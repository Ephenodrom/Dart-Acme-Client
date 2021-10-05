import 'package:acme_client/src/AcmeUtils.dart';
import 'package:acme_client/src/model/Authorization.dart';
import 'package:acme_client/src/model/Challenge.dart';
import 'package:acme_client/src/model/Identifiers.dart';
import 'package:jose/jose.dart';
import 'package:test/test.dart';

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

    expect(rr.data, 'NfbH84IEcqJiJB9RlXQ18shpjuemSJjY54hJuXTjyNs');
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
}
