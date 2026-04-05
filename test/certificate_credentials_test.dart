import 'package:acme_client/acme_client.dart';
import 'package:test/test.dart';

void main() {
  test('CertificateCredentials can be generated from identifiers', () {
    final credentials = CertificateCredentials.generate(
      identifiers: const [DomainIdentifier('example.com')],
    );

    expect(credentials.privateKeyPem, contains('BEGIN'));
    expect(credentials.publicKeyPem, contains('BEGIN'));
    expect(credentials.csrPem, contains('BEGIN CERTIFICATE REQUEST'));
    expect(credentials.identifiers.single.value, 'example.com');
  });

  test('CertificateCredentials round-trip through JSON', () {
    final credentials = CertificateCredentials.generate(
      identifiers: const [
        DomainIdentifier('example.com'),
        DomainIdentifier('www.example.com'),
      ],
    );

    final restored = CertificateCredentials.fromJson(credentials.toJson());

    expect(restored.privateKeyPem, credentials.privateKeyPem);
    expect(restored.publicKeyPem, credentials.publicKeyPem);
    expect(restored.csrPem, credentials.csrPem);
    expect(
      restored.identifiers.map((identifier) => identifier.value).toList(),
      ['example.com', 'www.example.com'],
    );
  });

  test('CertificateCredentials.generate rejects an empty identifier list', () {
    expect(
      () => CertificateCredentials.generate(identifiers: const []),
      throwsArgumentError,
    );
  });
}
