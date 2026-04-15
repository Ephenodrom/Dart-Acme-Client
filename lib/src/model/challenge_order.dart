import '../acme_client_exception.dart';
import '../acme_connection.dart';
import '../certificate_credentials.dart';
import 'account.dart';
import 'authorization.dart';
import 'challenge.dart';
import 'challenge_type.dart';
import 'dns_challenge.dart';
import 'dns_persist_challenge.dart';
import 'http_challenge.dart';
import 'identifiers.dart';
import 'order.dart';

/// @Throwing(UnsupportedError)
ChallengeType acmeChallengeTypeFor<TChallenge extends Challenge>() {
  if (TChallenge == DnsChallenge) {
    return ChallengeType.dns;
  }
  if (TChallenge == HttpChallenge) {
    return ChallengeType.http;
  }
  if (TChallenge == DnsPersistChallenge) {
    return ChallengeType.dnsPersist;
  }
  throw UnsupportedError('Unsupported challenge type: $TChallenge');
}

/// A typed ACME order bound to one chosen challenge workflow.
///
/// You obtain this from one of the `Account.createOrderFor...` methods. It
/// carries the order through the rest of the issuance flow:
///
/// 1. get an authorization for a domain
/// 2. get the concrete challenge
/// 3. publish and validate the proof
/// 4. finalize the order with [CertificateCredentials]
/// 5. fetch the issued certificate chain
class ChallengeOrder<TChallenge extends Challenge> {
  ChallengeOrder.internal(this._order, this._connection, this._account);

  Order _order;
  final AcmeConnection _connection;
  final Account _account;

  /// @Throwing(UnsupportedError)
  ChallengeType get challengeType => acmeChallengeTypeFor<TChallenge>();

  /// Returns whether the ACME order is ready to be finalized.
  ///
  /// An order usually becomes ready after all required authorizations have been
  /// validated successfully.
  Future<bool> isReady() => _order.isReady();

  /// Finalizes the order using the CSR contained in [credentials].
  ///
  /// This is the step where the CA turns a validated order into an actual
  /// certificate issuance. The supplied [CertificateCredentials] represent the
  /// certificate keypair and CSR, not the ACME account keypair.
  ///
  /// Call this only after challenge validation has succeeded and [isReady]
  /// returns `true`.
  /// @Throwing(AcmeConfigurationException)
  Future<void> finalize(
    CertificateCredentials credentials, {
    int retries = 5,
  }) async {
    final orderIdentifiers = (_order.identifiers ?? const [])
        .whereType<DomainIdentifier>()
        .map((identifier) => identifier.value)
        .toSet();
    final certificateIdentifiers = credentials.identifiers
        .map((identifier) => identifier.value)
        .toSet();
    if (orderIdentifiers.isNotEmpty &&
        (orderIdentifiers.length != certificateIdentifiers.length ||
            !orderIdentifiers.containsAll(certificateIdentifiers))) {
      throw const AcmeConfigurationException(
        'Certificate credentials do not match the identifiers on this order',
      );
    }
    _order = await _order.finalize(credentials.csrPem, retries: retries);
  }

  /// Downloads the issued certificate chain for the finalized order.
  ///
  /// Call this after [finalize] has completed successfully. The returned list
  /// contains the PEM-encoded certificates delivered by the CA.
  Future<List<String>> getCertificates() => _order.getCertificates();

  /// Returns the authorization for [identifier] in this typed workflow.
  ///
  /// The returned [ChallengeAuthorization] is still tied to the chosen
  /// challenge type for the order. The next step is usually `getChallenge()`.
  /// @Throwing(AcmeAuthorizationException)
  Future<ChallengeAuthorization<TChallenge>> getAuthorization(
    DomainIdentifier identifier,
  ) async {
    final authorizations = await _order.getAuthorizations();
    final matching = _order.authorizationsForIdentifier(
      identifier,
      authorizations,
    );
    for (final authorization in matching) {
      if (authorization.hasChallenge(challengeType: challengeType)) {
        authorization.challengeType = challengeType;
        return ChallengeAuthorization._(
          authorization,
          _connection,
          _account,
          identifier,
        );
      }
    }

    throw AcmeAuthorizationException(
      'The ACME server does not support the requested challenge type for this identifier',
      detail: '${identifier.value} (${challengeType.wireValue})',
      rawBody: matching
          .map(
            (authorization) => {
              'identifier': authorization.identifier?.value,
              'supportedChallengeTypes': authorization.challenges
                  ?.map((challenge) => challenge.type)
                  .toList(),
            },
          )
          .toList(),
    );
  }
}

/// A typed view of one authorization within a [ChallengeOrder].
///
/// This exists so callers can move from "the order contains an authorization
/// for this domain" to "give me the concrete challenge I should satisfy".
class ChallengeAuthorization<TChallenge extends Challenge> {
  ChallengeAuthorization._(
    this._authorization,
    this._connection,
    this._account,
    this._identifier,
  );

  final Authorization _authorization;
  final AcmeConnection _connection;
  final Account _account;
  final DomainIdentifier _identifier;

  /// Returns the concrete challenge for this authorization.
  ///
  /// The returned challenge is already enriched with the local execution
  /// context it needs to build proofs, run self-tests, and trigger validation.
  TChallenge getChallenge() {
    final challenge =
        _authorization.getChallenge(challengeType: _authorization.challengeType)
            as TChallenge;
    return acmeChallengeAttachExecutionContext(
          challenge,
          connection: _connection,
          account: _account,
          identifier: _identifier,
        )
        as TChallenge;
  }
}
// Public API docs intentionally keep some long protocol explanations unwrapped.
// ignore_for_file: lines_longer_than_80_chars
