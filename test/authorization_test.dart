import 'package:acme_client/acme_client.dart';
import 'package:jose/jose.dart';
import 'package:test/test.dart';

/// @Throwing(ArgumentError, reason: 'test setup may construct incomplete authorization data for the model helpers')
void main() {
  test('Test getDnsDcvData()', () {
    var digest = AcmeUtils.getDigest(JsonWebKey.fromJson({
      'e': 'AQAB',
      'kty': 'RSA',
      'n':
          'qE0KH1Os4O941MUZc6Pam9qdtEoF7Xgy5O1z5QVSAxObd1KtTvrNSS2U50NMn1_Zi5kwnWS1Ov9q71PygmyKA3h1UcLWukGe8zWtGlDxPwACZIZixYP3AHiMDUSSHqQSwRtYLUFr5Wye0SEDbPd22KPVAkoX4YxOeyE5uDTGPRCKWC_DdCjt7INzXWvP_kUeFy541aiSd0bZ82PH2WNY73krUFZM2NHHqXiN0VdhzVDeI9MoVX8Pm8lk5SotXWxH7Y6iVqllG98X83X_OKMAyajsgN8t2oe12OZFMf18MUHO1EBq9ZJzZQTLEDgI5Egr8Pcx46RWH_3FlScCEFoFYw'
    }));

    var auth = Authorization(
      digest: digest,
      identifier: Identifiers(type: 'dns', value: 'foobar.de'),
      challenges: [
        Challenge(
            type: 'dns-01',
            token: 'ngS9XDfXiScfg1Pteiza1lL4ngM0-wH0yZ7777BJTzE')
      ],
    );

    var rr = auth.getDnsDcvData().rRecord;
    var bind = auth.getDnsDcvData().toBindString();

    expect(rr.data, 'NfbH84IEcqJiJB9RlXQ18shpjuemSJjY54hJuXTjyNs');
    expect(bind, contains('_acme-challenge.foobar.de'));
  });

  test('Test getHttpDcvData()', () {
    var digest = AcmeUtils.getDigest(JsonWebKey.fromJson({
      'e': 'AQAB',
      'kty': 'RSA',
      'n':
          'qE0KH1Os4O941MUZc6Pam9qdtEoF7Xgy5O1z5QVSAxObd1KtTvrNSS2U50NMn1_Zi5kwnWS1Ov9q71PygmyKA3h1UcLWukGe8zWtGlDxPwACZIZixYP3AHiMDUSSHqQSwRtYLUFr5Wye0SEDbPd22KPVAkoX4YxOeyE5uDTGPRCKWC_DdCjt7INzXWvP_kUeFy541aiSd0bZ82PH2WNY73krUFZM2NHHqXiN0VdhzVDeI9MoVX8Pm8lk5SotXWxH7Y6iVqllG98X83X_OKMAyajsgN8t2oe12OZFMf18MUHO1EBq9ZJzZQTLEDgI5Egr8Pcx46RWH_3FlScCEFoFYw'
    }));

    var auth = Authorization(
      digest: digest,
      identifier: Identifiers(type: 'dns', value: 'foobar.de'),
      challenges: [
        Challenge(
            type: 'http-01',
            token: 'ngS9XDfXiScfg1Pteiza1lL4ngM0-wH0yZ7777BJTzE')
      ],
    );

    var httpDcvData = auth.getHttpDcvData();

    expect(httpDcvData.fileContent,
        'ngS9XDfXiScfg1Pteiza1lL4ngM0-wH0yZ7777BJTzE.UHnliA-nHylv8CpsdY9XsuZyvKLyWTq-4QpKx8V62H4');
    expect(httpDcvData.fileName,
        'foobar.de/.well-known/acme-challenge/ngS9XDfXiScfg1Pteiza1lL4ngM0-wH0yZ7777BJTzE');
  });

  test('Test buildDnsPersistDcvData()', () {
    final client = AcmeClient(
      'https://acme-staging-v02.api.letsencrypt.org',
      'private',
      'public',
      true,
      ['mailto:admin@example.com'],
    )..account = Account(accountURL: 'https://ca.example/acme/acct/123');

    final auth = Authorization(
      identifier: Identifiers(type: 'dns', value: 'example.com'),
      challenges: [
        Challenge(
          type: VALIDATION_DNS_PERSIST,
          url: 'https://example.com/acme/challenge/1',
          authorizationUrl: 'https://example.com/acme/authz/1',
          issuerDomainNames: ['ca.example', 'backup-ca.example'],
        ),
      ],
    );

    final dcvData = client.buildDnsPersistDcvData(
      auth,
      issuerDomainName: 'ca.example',
      policy: 'wildcard',
      persistUntil: DateTime.utc(2026, 1, 1),
    );

    expect(dcvData.rRecord.name, '_validation-persist.example.com');
    expect(
      dcvData.rRecord.data,
      'ca.example; accounturi=https://ca.example/acme/acct/123; '
      'policy=wildcard; persistUntil=1767225600',
    );
    expect(dcvData.toBindString(), contains('_validation-persist.example.com'));
    expect(dcvData.issuerDomainName, 'ca.example');
    expect(dcvData.accountUri, 'https://ca.example/acme/acct/123');
  });
}
