import 'dart:convert';

import 'package:basic_utils/basic_utils.dart';

import '../acme_client.dart' show Account;

import 'model/account.dart' show Account;

/// The long-lived credentials that identify your ACME account.
///
/// These credentials are used to create or fetch the ACME account itself and
/// should be persisted for later runs and renewals. They are not the same as
/// the certificate credentials used to build a CSR for a specific certificate.
class AcmeAccountCredentials {
  final String privateKeyPem;
  final String publicKeyPem;
  final bool acceptTerms;
  final List<String> contacts;

  /// Creates a set of ACME account credentials from existing PEM values.
  ///
  /// Use this when you already loaded the account keypair from secure storage.
  const AcmeAccountCredentials({
    required this.privateKeyPem,
    required this.publicKeyPem,
    required this.acceptTerms,
    required this.contacts,
  });

  /// Generates a fresh ACME account keypair.
  ///
  /// Call this when bootstrapping a new account for the first time, then
  /// persist the resulting credentials and reuse them with [Account.fetch] on
  /// later runs.
  factory AcmeAccountCredentials.generate({
    required List<String> contacts,
    bool acceptTerms = false,
    int rsaKeySize = 2048,
  }) {
    final accountKeyPair = CryptoUtils.generateRSAKeyPair(keySize: rsaKeySize);
    return AcmeAccountCredentials(
      privateKeyPem: CryptoUtils.encodeRSAPrivateKeyToPem(
        accountKeyPair.privateKey as RSAPrivateKey,
      ),
      publicKeyPem: CryptoUtils.encodeRSAPublicKeyToPem(
        accountKeyPair.publicKey as RSAPublicKey,
      ),
      acceptTerms: acceptTerms,
      contacts: List.unmodifiable(contacts),
    );
  }

  /// Restores account credentials from a decoded JSON map.
  factory AcmeAccountCredentials.fromMap(Map<String, dynamic> json) =>
      AcmeAccountCredentials(
        privateKeyPem: json['privateKeyPem'] as String,
        publicKeyPem: json['publicKeyPem'] as String,
        acceptTerms: json['acceptTerms'] as bool,
        contacts: (json['contacts'] as List<Object?>).cast<String>(),
      );

  /// Restores account credentials from a JSON string previously produced by
  /// [toJson].
  factory AcmeAccountCredentials.fromJson(String jsonString) =>
      AcmeAccountCredentials.fromMap(
        jsonDecode(jsonString) as Map<String, dynamic>,
      );

  /// Converts these credentials into a JSON-compatible map for persistence.
  Map<String, dynamic> toMap() => {
    'privateKeyPem': privateKeyPem,
    'publicKeyPem': publicKeyPem,
    'acceptTerms': acceptTerms,
    'contacts': contacts,
  };

  /// Serializes these credentials for storage outside the repository.
  String toJson({bool pretty = true}) => pretty
      ? const JsonEncoder.withIndent('  ').convert(toMap())
      : jsonEncode(toMap());
}
