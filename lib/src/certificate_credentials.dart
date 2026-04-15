import 'dart:convert';

import 'package:basic_utils/basic_utils.dart';

import '../acme_client.dart' show AcmeAccountCredentials, ChallengeOrder;
import 'model/identifiers.dart';

/// The certificate-side credentials for one certificate request.
///
/// This bundles the certificate private key, public key, and CSR for a
/// specific set of identifiers. It is separate from [AcmeAccountCredentials],
/// which identify the ACME account itself.
///
/// In the issuance flow, you usually generate or load these before calling
/// [ChallengeOrder.finalize].
class CertificateCredentials {
  final String privateKeyPem;
  final String publicKeyPem;
  final String csrPem;
  final List<DomainIdentifier> identifiers;

  /// Creates certificate credentials from existing PEM values and identifiers.
  ///
  /// Use this when you already loaded a certificate keypair and CSR from
  /// storage, for example during renewals.
  const CertificateCredentials({
    required this.privateKeyPem,
    required this.publicKeyPem,
    required this.csrPem,
    required this.identifiers,
  });

  /// Generates a new certificate keypair and CSR for [identifiers].
  ///
  /// This is the common-case helper for callers who do not already have CSR
  /// tooling. The generated CSR is suitable for [ChallengeOrder.finalize].
  ///
  /// Reuse the same stored credentials on renewal if you want to keep the same
  /// certificate private key. Generate new credentials on renewal if you want
  /// key rotation.
  /// @Throwing(ArgumentError)
  factory CertificateCredentials.generate({
    required List<DomainIdentifier> identifiers,
    int rsaKeySize = 2048,
    String? organizationName,
    String? organizationalUnit,
    String? locality,
    String? state,
    String? country,
  }) {
    if (identifiers.isEmpty) {
      throw ArgumentError.value(
        identifiers,
        'identifiers',
        'At least one identifier is required to build a CSR',
      );
    }

    final keyPair = CryptoUtils.generateRSAKeyPair(keySize: rsaKeySize);
    final privateKey = keyPair.privateKey as RSAPrivateKey;
    final publicKey = keyPair.publicKey as RSAPublicKey;
    final subjectNames = identifiers
        .map((identifier) => identifier.value)
        .whereType<String>()
        .toList(growable: false);
    final attributes = <String, String>{'CN': subjectNames.first};
    if (organizationName != null) {
      attributes['O'] = organizationName;
    }
    if (organizationalUnit != null) {
      attributes['OU'] = organizationalUnit;
    }
    if (locality != null) {
      attributes['L'] = locality;
    }
    if (state != null) {
      attributes['ST'] = state;
    }
    if (country != null) {
      attributes['C'] = country;
    }
    final csrPem = X509Utils.generateRsaCsrPem(
      attributes,
      privateKey,
      publicKey,
      san: subjectNames,
    );

    return CertificateCredentials(
      privateKeyPem: CryptoUtils.encodeRSAPrivateKeyToPem(privateKey),
      publicKeyPem: CryptoUtils.encodeRSAPublicKeyToPem(publicKey),
      csrPem: csrPem,
      identifiers: List.unmodifiable(identifiers),
    );
  }

  /// Restores certificate credentials from a decoded JSON map.
  factory CertificateCredentials.fromMap(Map<String, dynamic> json) =>
      CertificateCredentials(
        privateKeyPem: json['privateKeyPem'] as String,
        publicKeyPem: json['publicKeyPem'] as String,
        csrPem: json['csrPem'] as String,
        identifiers: (json['identifiers'] as List<Object?>)
            .cast<String>()
            .map(DomainIdentifier.new)
            .toList(growable: false),
      );

  /// Restores certificate credentials from a JSON string previously produced by
  /// [toJson].
  factory CertificateCredentials.fromJson(String jsonString) =>
      CertificateCredentials.fromMap(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );

  /// Converts these certificate credentials into a JSON-compatible map.
  Map<String, dynamic> toMap() => {
    'privateKeyPem': privateKeyPem,
    'publicKeyPem': publicKeyPem,
    'csrPem': csrPem,
    'identifiers': identifiers.map((identifier) => identifier.value).toList(),
  };

  /// Serializes these certificate credentials for storage.
  String toJson({bool pretty = true}) => pretty
      ? const JsonEncoder.withIndent('  ').convert(toMap())
      : jsonEncode(toMap());
}
