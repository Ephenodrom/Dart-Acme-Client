import 'package:acme_client/src/acme_account_credentials.dart';
import 'package:acme_client/src/account_key_digest.dart';
import 'package:acme_client/src/acme_client_exception.dart';
import 'package:acme_client/src/acme_jws_manager.dart';
import 'package:acme_client/src/acme_logger.dart';
import 'package:acme_client/src/model/account.dart';
import 'package:acme_client/src/model/acme_directories.dart';
import 'package:acme_client/src/model/challenge.dart';
import 'package:acme_client/src/model/dns_dcv_data.dart';
import 'package:acme_client/src/model/dns_persist_challenge_data.dart';
import 'package:acme_client/src/model/http_dcv_data.dart';
import 'package:acme_client/src/wire/authorization_resource.dart';
import 'package:acme_client/src/wire/acme_directories_resource.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:dio/dio.dart';

class AcmeConnection {
  static const letsEncryptDirectoryUrl =
      'https://acme-v02.api.letsencrypt.org/directory';
  static const letsEncryptStagingDirectoryUrl =
      'https://acme-staging-v02.api.letsencrypt.org/directory';
  static const production = AcmeConnection.letsEncrypt();
  static const staging = AcmeConnection.letsEncryptStaging();

  final String baseUrl;
  final Dio? dio;
  final AcmeLogFn? logger;
  final _AcmeConnectionSession? _session;

  const AcmeConnection({
    this.baseUrl = letsEncryptDirectoryUrl,
    this.dio,
    this.logger,
  }) : _session = null;

  const AcmeConnection.letsEncrypt({this.dio, this.logger})
    : baseUrl = letsEncryptDirectoryUrl,
      _session = null;

  const AcmeConnection.letsEncryptStaging({this.dio, this.logger})
    : baseUrl = letsEncryptStagingDirectoryUrl,
      _session = null;

  AcmeConnection._bound({
    required this.baseUrl,
    required this.logger,
    required this.dio,
    required _AcmeConnectionSession session,
  }) : _session = session;

  AcmeConnection _bindCredentials(AcmeAccountCredentials credentials) {
    final resolvedDio = dio ?? Dio();
    return AcmeConnection._bound(
      baseUrl: baseUrl,
      logger: logger,
      dio: resolvedDio,
      session: _AcmeConnectionSession(
        dio: resolvedDio,
        logger: logger,
        credentials: credentials,
      ),
    );
  }

  Future<void> _init() async {
    _validateData();
    _requireSession().directories = await acmeDirectoriesFetch(
      _resolvedDio,
      baseUrl,
      onWrapped: (wrapped, exception, stackTrace) => _log(
        AcmeLogLevel.error,
        wrapped.message,
        error: exception,
        stackTrace: stackTrace,
      ),
    );
  }

  Future<bool> _validate(Challenge challenge, {int maxAttempts = 15}) async {
    final session = _requireSession();
    final validationPayload = challenge.createValidationPayload(
      accountKeyDigestProvider: () => _accountKeyDigest,
    );
    final jws = await session.jwsManager.createJws(
      challenge.url!,
      newNonceUrl: session.directories?.newNonce,
      accountUrl: session.account?.accountURL,
      useKid: true,
      payload: validationPayload,
    );
    const headers = {'Content-Type': 'application/jose+json'};
    try {
      final response = await _resolvedDio.post(
        challenge.url!,
        data: jws.toJson(),
        options: Options(headers: headers),
      );
      session.jwsManager.updateNonce(response);
    } on DioException catch (e, s) {
      session.jwsManager.captureErrorNonce(e);
      throw AcmeClientException.wrapDioException(
        e,
        'Failed to trigger ACME challenge validation',
        AcmeValidationException.fromDioException,
        onWrapped: (wrapped) =>
            _log(AcmeLogLevel.error, wrapped.message, error: e, stackTrace: s),
      );
    }

    while (maxAttempts > 0) {
      final pollJws = await session.jwsManager.createJws(
        challenge.authorizationUrl!,
        newNonceUrl: session.directories?.newNonce,
        accountUrl: session.account?.accountURL,
        useKid: true,
      );

      try {
        final response = await _resolvedDio.post(
          challenge.authorizationUrl!,
          data: pollJws.toJson(),
          options: Options(headers: headers),
        );
        session.jwsManager.updateNonce(response);
        final auth = acmeAuthorizationFromResponse(
          response,
          authorizationUrl: challenge.authorizationUrl!,
        );
        if (auth.status == 'valid') {
          return true;
        }
        if (auth.status == 'invalid') {
          throw AcmeValidationException.fromChallengeFailure(
            response.data,
            uri: Uri.tryParse(challenge.authorizationUrl!),
            rawBody: response.data,
          );
        }
      } on DioException catch (e, s) {
        session.jwsManager.captureErrorNonce(e);
        throw AcmeClientException.wrapDioException(
          e,
          'Failed while polling ACME challenge authorization',
          AcmeValidationException.fromDioException,
          onWrapped: (wrapped) => _log(
            AcmeLogLevel.error,
            wrapped.message,
            error: e,
            stackTrace: s,
          ),
        );
      }
      maxAttempts--;
      if (maxAttempts > 0) {
        await Future.delayed(const Duration(seconds: 4));
      }
    }

    throw AcmeValidationException(
      'Timed out waiting for ACME challenge validation',
      uri: Uri.tryParse(challenge.authorizationUrl ?? challenge.url ?? ''),
    );
  }

  Future<bool> _selfDnsTest(DnsChallengeData data, {int maxAttempts = 15}) async {
    for (var i = 0; i < maxAttempts; i++) {
      final records = await DnsUtils.lookupRecord(
        data.txtRecordName,
        RRecordType.TXT,
        provider: DnsApiProvider.GOOGLE,
      );
      if (records != null &&
          records.isNotEmpty &&
          records.first.data == data.txtRecordValue) {
        _log(AcmeLogLevel.debug, 'Found record via Google DNS');
        return true;
      }
      _log(AcmeLogLevel.debug, 'DNS record not visible via Google DNS yet');
      await Future.delayed(const Duration(seconds: 4));
    }
    return false;
  }

  Future<bool> _selfDnsPersistTest(
    DnsPersistChallengeData data, {
    int maxAttempts = 15,
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      final records = await DnsUtils.lookupRecord(
        data.txtRecordName,
        RRecordType.TXT,
        provider: DnsApiProvider.GOOGLE,
      );
      if (records != null &&
          records.isNotEmpty &&
          records.any((record) => record.data == data.txtRecordValue)) {
        _log(AcmeLogLevel.debug, 'Found persistent DNS record via Google DNS');
        return true;
      }
      _log(
        AcmeLogLevel.debug,
        'Persistent DNS record not visible via Google DNS yet',
      );
      await Future.delayed(const Duration(seconds: 4));
    }
    return false;
  }

  Future<bool> _selfHttpTest(HttpChallengeData data, {int maxAttempts = 15}) async {
    for (var i = 0; i < maxAttempts; i++) {
      try {
        final response = await _resolvedDio.get(data.fileName);
        if (response.data is String && response.data(String) == data.fileContent) {
          return true;
        }
      } on DioException catch (e, s) {
        _log(
          AcmeLogLevel.debug,
          'HTTP self-test request failed',
          error: e,
          stackTrace: s,
        );
      }
      await Future.delayed(const Duration(seconds: 4));
    }
    return false;
  }

  AcmeAccountCredentials _toAccountCredentials() {
    final credentials = _requireSession().credentials;
    return AcmeAccountCredentials(
      privateKeyPem: credentials.privateKeyPem,
      publicKeyPem: credentials.publicKeyPem,
      acceptTerms: credentials.acceptTerms,
      contacts: List.unmodifiable(credentials.contacts),
    );
  }

  void _validateData() {
    final credentials = _requireSession().credentials;
    for (final element in credentials.contacts) {
      if (!element.startsWith('mailto')) {
        throw const AcmeConfigurationException(
          'Given contacts have to start with "mailto:"',
        );
      }
    }

    if (StringUtils.isNullOrEmpty(baseUrl)) {
      throw const AcmeConfigurationException('baseUrl is missing');
    }

    if (StringUtils.isNullOrEmpty(credentials.publicKeyPem)) {
      throw const AcmeConfigurationException('Public key PEM is missing');
    }
  }

  _AcmeConnectionSession _requireSession() =>
      _session ??
      (throw StateError('AcmeConnection is not bound to account credentials'));

  Dio get _resolvedDio => _requireSession().dio;

  AcmeJwsManager get _jwsManager => _requireSession().jwsManager;

  String get _accountKeyDigest => acmeAccountKeyDigestFromPublicKeyPem(
    _requireSession().credentials.publicKeyPem,
  );

  void _bindAccount(Account account) {
    _requireSession().account = account;
  }

  Account? get _account => _session?.account;

  AcmeDirectories? get _directories => _session?.directories;

  bool get _acceptTerms => _requireSession().credentials.acceptTerms;

  List<String> get _contacts => _requireSession().credentials.contacts;

  void _setTestNonce(String? value) {
    _requireSession().jwsManager.nonce = value;
  }

  String? get _testNonce => _session?.jwsManager.nonce;

  void _setTestAccount(Account? value) {
    _requireSession().account = value;
  }

  void _setTestDirectories(AcmeDirectories? value) {
    _requireSession().directories = value;
  }

  void _log(
    AcmeLogLevel level,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    logger?.call(level, message, error: error, stackTrace: stackTrace);
  }
}

/// Binds account credentials to an immutable connection configuration.
///
/// Why this exists: package code needs a credential-bound ACME session, but we
/// do not want that construction step to appear as an instance API on the
/// public `AcmeConnection` type.
AcmeConnection acmeConnectionBindCredentials(
  AcmeConnection connection,
  AcmeAccountCredentials credentials,
) => connection._bindCredentials(credentials);

/// Loads the ACME directory for a bound connection.
///
/// Why this exists: `Account.create` and `Account.fetch` need this bootstrap
/// step, but it is an implementation detail rather than part of the public
/// `AcmeConnection` API.
Future<void> acmeConnectionInit(AcmeConnection connection) => connection._init();

/// Triggers and polls an ACME challenge validation using the bound account.
///
/// Why this exists: end users validate via `Account.validate`, so the wire
/// protocol entrypoint should stay off the public `AcmeConnection` docs.
Future<bool> acmeConnectionValidate(
  AcmeConnection connection,
  Challenge challenge, {
  int maxAttempts = 15,
}) => connection._validate(challenge, maxAttempts: maxAttempts);

/// Checks whether a DNS-01 TXT record is publicly visible.
///
/// Why this exists: callers use the higher-level `Account.selfDNSTest`, so the
/// connection-level helper remains a package implementation detail.
Future<bool> acmeConnectionSelfDnsTest(
  AcmeConnection connection,
  DnsChallengeData data, {
  int maxAttempts = 15,
}) => connection._selfDnsTest(data, maxAttempts: maxAttempts);

/// Checks whether a dns-persist-01 TXT record is publicly visible.
///
/// Why this exists: it supports the fluent account API without exposing another
/// connection-level operational method in the generated docs.
Future<bool> acmeConnectionSelfDnsPersistTest(
  AcmeConnection connection,
  DnsPersistChallengeData data, {
  int maxAttempts = 15,
}) => connection._selfDnsPersistTest(data, maxAttempts: maxAttempts);

/// Checks whether an HTTP-01 response body is visible at the challenge URL.
///
/// Why this exists: the public self-test entrypoint lives on `Account`, not on
/// the connection configuration object.
Future<bool> acmeConnectionSelfHttpTest(
  AcmeConnection connection,
  HttpChallengeData data, {
  int maxAttempts = 15,
}) => connection._selfHttpTest(data, maxAttempts: maxAttempts);

/// Recreates the credential value currently bound to the connection session.
///
/// Why this exists: `Account.toAccountCredentials` needs access to the bound
/// session data, but the session itself should stay hidden from API consumers.
AcmeAccountCredentials acmeConnectionToAccountCredentials(
  AcmeConnection connection,
) => connection._toAccountCredentials();

/// Validates that the bound connection has the minimum required account data.
///
/// Why this exists: tests and bootstrap code need deterministic validation
/// without making `validateData` part of the public class API.
void acmeConnectionValidateData(AcmeConnection connection) =>
    connection._validateData();

/// Returns the Dio instance for the bound connection session.
///
/// Why this exists: package-internal protocol code needs transport access, but
/// that transport should not surface as a public `AcmeConnection` getter.
Dio acmeConnectionResolvedDio(AcmeConnection connection) => connection._resolvedDio;

/// Returns the JWS manager for the bound connection session.
///
/// Why this exists: model-layer protocol calls need signing support, but the
/// signing machinery is an internal implementation detail.
AcmeJwsManager acmeConnectionJwsManager(AcmeConnection connection) =>
    connection._jwsManager;

/// Computes the account key digest for the bound credential set.
///
/// Why this exists: challenge helpers need the digest while the underlying
/// credential/session plumbing stays hidden from the public class surface.
String acmeConnectionAccountKeyDigest(AcmeConnection connection) =>
    connection._accountKeyDigest;

/// Attaches an account model to the bound connection session.
///
/// Why this exists: fluent account/order operations need session affinity, but
/// that wiring should not appear as a public method on `AcmeConnection`.
void acmeConnectionBindAccount(AcmeConnection connection, Account account) =>
    connection._bindAccount(account);

/// Returns the bound account, if any.
///
/// Why this exists: package tests and sibling libraries need to inspect the
/// active session state without exposing it as public object API.
Account? acmeConnectionAccount(AcmeConnection connection) => connection._account;

/// Returns the discovered ACME directories, if they have been loaded.
///
/// Why this exists: internal protocol calls need directory URLs while keeping
/// directory state out of the public `AcmeConnection` documentation.
AcmeDirectories? acmeConnectionDirectories(AcmeConnection connection) =>
    connection._directories;

/// Returns whether the bound credentials accept the CA terms.
///
/// Why this exists: account creation/fetch helpers need this flag, but it is
/// session state rather than part of the user-facing connection API.
bool acmeConnectionAcceptTerms(AcmeConnection connection) =>
    connection._acceptTerms;

/// Returns the bound contact list.
///
/// Why this exists: account request payload construction needs the contacts
/// without exposing session-bound values on the public class.
List<String> acmeConnectionContacts(AcmeConnection connection) =>
    connection._contacts;

/// Sets the replay nonce for tests.
///
/// Why this exists: tests need deterministic nonce control, but nonce mutation
/// should never appear in public API docs for `AcmeConnection`.
void acmeConnectionTestSetNonce(AcmeConnection connection, String? value) =>
    connection._setTestNonce(value);

/// Reads the replay nonce for tests.
///
/// Why this exists: tests sometimes need to assert or inspect nonce state while
/// keeping that state out of the public connection API.
String? acmeConnectionTestNonce(AcmeConnection connection) => connection._testNonce;

/// Injects a test account into the bound session.
///
/// Why this exists: exception-path tests need a seeded session without exposing
/// mutable account hooks on the public `AcmeConnection` type.
void acmeConnectionTestSetAccount(AcmeConnection connection, Account? value) =>
    connection._setTestAccount(value);

/// Injects discovered directories for tests.
///
/// Why this exists: tests need to bypass network discovery, but directory
/// injection belongs in test support rather than public API docs.
void acmeConnectionTestSetDirectories(
  AcmeConnection connection,
  AcmeDirectories? value,
) => connection._setTestDirectories(value);

class _AcmeConnectionSession {
  _AcmeConnectionSession({
    required this.dio,
    required this.credentials,
    required AcmeLogFn? logger,
  }) : jwsManager = AcmeJwsManager(
         dio,
         credentials.privateKeyPem,
         credentials.publicKeyPem,
         logger: logger,
       );

  final Dio dio;
  final AcmeAccountCredentials credentials;
  final AcmeJwsManager jwsManager;
  AcmeDirectories? directories;
  Account? account;
}
