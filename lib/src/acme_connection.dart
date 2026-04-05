import 'package:basic_utils/basic_utils.dart';
import 'package:dio/dio.dart';

import 'account_key_digest.dart';
import 'acme_account_credentials.dart';
import 'acme_client_exception.dart';
import 'acme_exception_factory.dart';
import 'acme_jws_manager.dart';
import 'acme_logger.dart';
import 'model/account.dart';
import 'model/acme_directories.dart';
import 'model/challenge.dart';
import 'model/challenge_validation.dart';
import 'model/dns_challenge_proof.dart';
import 'model/dns_persist_challenge_proof.dart';
import 'model/http_challenge_proof.dart';
import 'wire/acme_directories_resource.dart';
import 'wire/authorization_resource.dart';

/// Immutable configuration for talking to one ACME server.
///
/// Most callers create a connection once, choose the appropriate preset
/// (`letsEncrypt`, `letsEncryptStaging`, or `pebble`), and then pass it to
/// [Account.create] or [Account.fetch]. The connection also carries optional
/// transport and logging configuration used throughout the flow.
class AcmeConnection {
  static const letsEncryptDirectoryUrl =
      'https://acme-v02.api.letsencrypt.org/directory';
  static const letsEncryptStagingDirectoryUrl =
      'https://acme-staging-v02.api.letsencrypt.org/directory';
  static const pebbleDirectoryUrl = 'https://localhost:14000/dir';
  static const production = AcmeConnection.letsEncrypt();
  static const staging = AcmeConnection.letsEncryptStaging();

  final String baseUrl;
  final Dio? _dio;
  final AcmeLogFn? logger;
  final _AcmeConnectionSession? _session;

  /// Creates a connection for a custom ACME directory URL.
  ///
  /// Use this when talking to a CA other than the built-in presets.
  const AcmeConnection({
    this.baseUrl = letsEncryptDirectoryUrl,
    Dio? dio,
    this.logger,
  }) : _dio = dio,
       _session = null;

  /// Creates a connection to Let's Encrypt production.
  ///
  /// This is the normal choice for real certificate issuance.
  const AcmeConnection.letsEncrypt({Dio? dio, this.logger})
    : baseUrl = letsEncryptDirectoryUrl,
      _dio = dio,
      _session = null;

  /// Creates a connection to Let's Encrypt staging.
  ///
  /// Use this for development and integration testing to avoid production rate
  /// limits while you are still building your flow.
  const AcmeConnection.letsEncryptStaging({Dio? dio, this.logger})
    : baseUrl = letsEncryptStagingDirectoryUrl,
      _dio = dio,
      _session = null;

  /// Creates a connection to a local Pebble test server.
  ///
  /// The default Pebble directory URL is `https://localhost:14000/dir`.
  /// Callers often also supply a custom `Dio` here so they can trust Pebble's
  /// local test certificate or disable certificate checks in a controlled test
  /// environment.
  const AcmeConnection.pebble({Dio? dio, this.logger})
    : baseUrl = pebbleDirectoryUrl,
      _dio = dio,
      _session = null;

  AcmeConnection._bound({
    required this.baseUrl,
    required this.logger,
    required Dio dio,
    required _AcmeConnectionSession session,
  }) : _dio = dio,
       _session = session;

  AcmeConnection _bindCredentials(AcmeAccountCredentials credentials) {
    final resolvedDio = _dio ?? Dio();
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

  /// @Throwing(AcmeConfigurationException)
  /// @Throwing(StateError)
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

  /// @Throwing(AcmeClientException)
  /// @Throwing(AcmeValidationException)
  /// @Throwing(StateError)
  Future<bool> _validate(Challenge challenge, {int maxAttempts = 15}) async {
    final session = _requireSession();
    final validationPayload = acmeChallengeCreateValidationPayload(challenge);
    final jws = await session.jwsManager.createJws(
      challenge.url!,
      newNonceUrl: session.directories?.newNonce,
      accountUrl: session.account?.accountURL,
      useKid: true,
      payload: validationPayload,
    );
    const headers = {'Content-Type': 'application/jose+json'};
    try {
      final response = await _resolvedDio.post<Map<String, Object?>>(
        challenge.url!,
        data: jws.toJson(),
        options: Options(headers: headers),
      );
      session.jwsManager.updateNonce(response);
    } on DioException catch (e, s) {
      session.jwsManager.captureErrorNonce(e);
      throw acmeWrapDioException(
        e,
        'Failed to trigger ACME challenge validation',
        acmeValidationExceptionFromDioException,
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
        final response = await _resolvedDio.post<Map<String, Object?>>(
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
          throw acmeValidationExceptionFromChallengeFailure(
            response.data,
            uri: Uri.tryParse(challenge.authorizationUrl!),
            rawBody: response.data,
          );
        }
      } on DioException catch (e, s) {
        session.jwsManager.captureErrorNonce(e);
        throw acmeWrapDioException(
          e,
          'Failed while polling ACME challenge authorization',
          acmeValidationExceptionFromDioException,
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
        await Future.delayed(const Duration(seconds: 4), () {});
      }
    }

    throw AcmeValidationException(
      'Timed out waiting for ACME challenge validation',
      uri: Uri.tryParse(challenge.authorizationUrl ?? challenge.url ?? ''),
    );
  }

  Future<bool> _selfDnsTest(
    DnsChallengeProof data, {
    int maxAttempts = 15,
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      final records = await DnsUtils.lookupRecord(
        data.txtRecordName,
        RRecordType.TXT,
      );
      if (records != null &&
          records.isNotEmpty &&
          records.first.data == data.txtRecordValue) {
        _log(AcmeLogLevel.debug, 'Found record via Google DNS');
        return true;
      }
      _log(AcmeLogLevel.debug, 'DNS record not visible via Google DNS yet');
      await Future.delayed(const Duration(seconds: 4), () {});
    }
    return false;
  }

  Future<bool> _selfDnsPersistTest(
    DnsPersistChallengeProof data, {
    int maxAttempts = 15,
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      final records = await DnsUtils.lookupRecord(
        data.txtRecordName,
        RRecordType.TXT,
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
      await Future.delayed(const Duration(seconds: 4), () {});
    }
    return false;
  }

  Future<bool> _selfHttpTest(
    HttpChallengeProof data, {
    int maxAttempts = 15,
  }) async {
    for (var i = 0; i < maxAttempts; i++) {
      try {
        final response = await _resolvedDio.get<String>(
          data.pathToWellKnownChallenge,
        );
        if (response.data == data.wellKnownChallengeFileContent) {
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
      await Future.delayed(const Duration(seconds: 4), () {});
    }
    return false;
  }

  /// @Throwing(StateError)
  AcmeAccountCredentials _toAccountCredentials() {
    final credentials = _requireSession().credentials;
    return AcmeAccountCredentials(
      privateKeyPem: credentials.privateKeyPem,
      publicKeyPem: credentials.publicKeyPem,
      acceptTerms: credentials.acceptTerms,
      contacts: List.unmodifiable(credentials.contacts),
    );
  }

  /// @Throwing(AcmeConfigurationException)
  /// @Throwing(StateError)
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

  /// @Throwing(StateError)
  _AcmeConnectionSession _requireSession() =>
      _session ??
      (throw StateError('AcmeConnection is not bound to account credentials'));

  /// @Throwing(StateError)
  Dio get _resolvedDio => _requireSession().dio;

  /// @Throwing(StateError)
  AcmeJwsManager get _jwsManager => _requireSession().jwsManager;

  /// @Throwing(StateError)
  String get _accountKeyDigest => acmeAccountKeyDigestFromPublicKeyPem(
    _requireSession().credentials.publicKeyPem,
  );

  /// @Throwing(StateError)
  void _bindAccount(Account account) {
    _requireSession().account = account;
  }

  Account? get _account => _session?.account;

  AcmeDirectories? get _directories => _session?.directories;

  /// @Throwing(StateError)
  bool get _acceptTerms => _requireSession().credentials.acceptTerms;

  /// @Throwing(StateError)
  List<String> get _contacts => _requireSession().credentials.contacts;

  /// @Throwing(StateError)
  void _setTestNonce(String? value) {
    _requireSession().jwsManager.nonce = value;
  }

  String? get _testNonce => _session?.jwsManager.nonce;

  /// @Throwing(StateError)
  void _setTestAccount(Account? value) {
    _requireSession().account = value;
  }

  /// @Throwing(StateError)
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
/// @Throwing(AcmeConfigurationException)
/// @Throwing(StateError)
Future<void> acmeConnectionInit(AcmeConnection connection) =>
    connection._init();

/// Triggers and polls an ACME challenge validation using the bound account.
///
/// Why this exists: end users validate via `Account.validate`, so the wire
/// protocol entrypoint should stay off the public `AcmeConnection` docs.
/// @Throwing(AcmeClientException)
/// @Throwing(AcmeValidationException)
/// @Throwing(StateError)
Future<bool> acmeConnectionValidate(
  AcmeConnection connection,
  Challenge challenge, {
  int maxAttempts = 15,
}) => connection._validate(challenge, maxAttempts: maxAttempts);

/// Checks whether a DNS-01 TXT record is publicly visible.
///
/// Why this exists: challenge-level `selfTest()` reuses the bound
/// [AcmeConnection] for logger output and shared client configuration, while
/// keeping the actual DNS probe logic off the public connection API. This does
/// not contact the CA.
Future<bool> acmeConnectionSelfDnsTest(
  AcmeConnection connection,
  DnsChallengeProof data, {
  int maxAttempts = 15,
}) => connection._selfDnsTest(data, maxAttempts: maxAttempts);

/// Checks whether a dns-persist-01 TXT record is publicly visible.
///
/// Why this exists: challenge-level `selfTest()` reuses the bound
/// [AcmeConnection] for logger output and shared client configuration, while
/// keeping the actual DNS probe logic off the public connection API. This does
/// not contact the CA.
Future<bool> acmeConnectionSelfDnsPersistTest(
  AcmeConnection connection,
  DnsPersistChallengeProof data, {
  int maxAttempts = 15,
}) => connection._selfDnsPersistTest(data, maxAttempts: maxAttempts);

/// Checks whether an HTTP-01 response body is visible at the challenge URL.
///
/// Why this exists: challenge-level `selfTest()` reuses the bound
/// [AcmeConnection] for logger output and shared HTTP client configuration,
/// while keeping the actual probe logic off the public connection API. This
/// does not contact the CA.
Future<bool> acmeConnectionSelfHttpTest(
  AcmeConnection connection,
  HttpChallengeProof data, {
  int maxAttempts = 15,
}) => connection._selfHttpTest(data, maxAttempts: maxAttempts);

/// Recreates the credential value currently bound to the connection session.
///
/// Why this exists: `Account.toAccountCredentials` needs access to the bound
/// session data, but the session itself should stay hidden from API consumers.
/// @Throwing(StateError)
AcmeAccountCredentials acmeConnectionToAccountCredentials(
  AcmeConnection connection,
) => connection._toAccountCredentials();

/// Validates that the bound connection has the minimum required account data.
///
/// Why this exists: tests and bootstrap code need deterministic validation
/// without making `validateData` part of the public class API.
/// @Throwing(AcmeConfigurationException)
/// @Throwing(StateError)
void acmeConnectionValidateData(AcmeConnection connection) =>
    connection._validateData();

/// Returns the Dio instance for the bound connection session.
///
/// Why this exists: package-internal protocol code needs transport access, but
/// that transport should not surface as a public `AcmeConnection` getter.
Dio acmeConnectionResolvedDio(AcmeConnection connection) =>
    connection._resolvedDio;

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
/// @Throwing(StateError)
void acmeConnectionBindAccount(AcmeConnection connection, Account account) =>
    connection._bindAccount(account);

/// Returns the bound account, if any.
///
/// Why this exists: package tests and sibling libraries need to inspect the
/// active session state without exposing it as public object API.
Account? acmeConnectionAccount(AcmeConnection connection) =>
    connection._account;

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
/// @Throwing(StateError)
void acmeConnectionTestSetNonce(AcmeConnection connection, String? value) =>
    connection._setTestNonce(value);

/// Reads the replay nonce for tests.
///
/// Why this exists: tests sometimes need to assert or inspect nonce state while
/// keeping that state out of the public connection API.
String? acmeConnectionTestNonce(AcmeConnection connection) =>
    connection._testNonce;

/// Injects a test account into the bound session.
///
/// Why this exists: exception-path tests need a seeded session without exposing
/// mutable account hooks on the public `AcmeConnection` type.
/// @Throwing(StateError)
void acmeConnectionTestSetAccount(AcmeConnection connection, Account? value) =>
    connection._setTestAccount(value);

/// Injects discovered directories for tests.
///
/// Why this exists: tests need to bypass network discovery, but directory
/// injection belongs in test support rather than public API docs.
/// @Throwing(StateError)
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

// Internal session helpers use imperative mutation for clarity in tests and
// bootstrapping code.
// ignore_for_file: use_setters_to_change_properties
