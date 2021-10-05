import 'package:acme_client/src/AcmeUtils.dart';
import 'package:jose/jose.dart';
import 'package:test/test.dart';

void main() {
  test('Test getDigest()', () {
    var key = JsonWebKey.fromJson({
      'e': 'AQAB',
      'kty': 'RSA',
      'n':
          '0vx7agoebGcQSuuPiLJXZptN9nndrQmbXEps2aiAFbWhM78LhWx4cbbfAAtVT86zwu1RK7aPFFxuhDR1L6tSoc_BJECPebWKRXjBZCiFV4n3oknjhMstn64tZ_2W-5JsGY4Hc5n9yBXArwl93lqt7_RN5w6Cf0h4QyQ5v-65YGjQR0_FDW2QvzqY368QQMicAtaSqzs8KJZgnYb9c7d0zgdAZHzu6qMQvRL5hajrn1n91CbOpbISD08qNLyrdkt-bFTWhAI4vMQFh6WeZu0fM4lFd2NcRwr3XPksINHaQ-G_xBniIqbw0Ls1jF44-csFCur-kEgU8awapJzKnqDKgw'
    });
    var digest = AcmeUtils.getDigest(key);
    expect(digest, 'NzbLsXh8uDCcd-6MNwXF4W_7noWXFZAfHkxZsRGC9Xs');

    key = JsonWebKey.fromJson({
      'e': 'AQAB',
      'kty': 'RSA',
      'n':
          '8AbMGh67sUedCJ2fKKRto-GoUl6cReZo2AjpaMT2K4F29eI1_i7AX7Z8r3kQBbcchDB7UVMZDJqsLcSaZD9CugvFdtM7hSMPlAubeqALun0ooxbFYGDVBs-k_7DoX8eXjxl_e1uxGeDmL3_upSiZuab0HbXOsQXjj9QgYJhn95Ja-58x9wcHHAp_oxoymcfC0wEAuBun1kszZG3zGr5JX78eaOJSszakiU44aBQeNqSIQb050rDF-mO1iNINGbd6X6bLpBaQGoZTaULEWuvTZyTumvTDLuYcD7PV2BCL7y4U3EQ7I5e7UOCV0hlwG1juGvsPqakCTnUa2yo62fN-yNgHoNltmlTK-DZHPZdiT_7Graiap0Nwbh81k2UYVzm2g_HYLCy8HZxSVAGzcAz26Q0D7hsdwqDl1YW3_LSZXysTnxDdKPUIfr49KMDg-56Ii6Ll2vHu-Oc1kyX3bVtMcyEC1LM23gHy_dIQOC8M1VKoylH4mcEWz4yEBpIT7dDlbWjG4OiHhtKu4tjiV1LinH0dH-0e54WIvxEcsLhgUvZ-He6-mwqMvv9o_1qrAuNy5Scpa0TG5x7jfaXMMxtskqDHs6DZHWIPt9oZi9FczGgmxSl8vCaLjqfy7Wew2_rAli8BKtznr_Y1p9w7KN75Xf3ZWRttWFCDBIeEs6MI8XM'
    });
    digest = AcmeUtils.getDigest(key);
    expect(digest, 'l70xxQ8Ez0PUndFEa5zevpysj3QQg-5_gYqIOb_XuqA');

    key = JsonWebKey.fromJson({
      'e': 'AQAB',
      'kty': 'RSA',
      'n':
          'qE0KH1Os4O941MUZc6Pam9qdtEoF7Xgy5O1z5QVSAxObd1KtTvrNSS2U50NMn1_Zi5kwnWS1Ov9q71PygmyKA3h1UcLWukGe8zWtGlDxPwACZIZixYP3AHiMDUSSHqQSwRtYLUFr5Wye0SEDbPd22KPVAkoX4YxOeyE5uDTGPRCKWC_DdCjt7INzXWvP_kUeFy541aiSd0bZ82PH2WNY73krUFZM2NHHqXiN0VdhzVDeI9MoVX8Pm8lk5SotXWxH7Y6iVqllG98X83X_OKMAyajsgN8t2oe12OZFMf18MUHO1EBq9ZJzZQTLEDgI5Egr8Pcx46RWH_3FlScCEFoFYw'
    });
    digest = AcmeUtils.getDigest(key);
    expect(digest, 'UHnliA-nHylv8CpsdY9XsuZyvKLyWTq-4QpKx8V62H4');

    key = JsonWebKey.fromPem('''-----BEGIN PUBLIC KEY-----
MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAqE0KH1Os4O941MUZc6Pa
m9qdtEoF7Xgy5O1z5QVSAxObd1KtTvrNSS2U50NMn1/Zi5kwnWS1Ov9q71PygmyK
A3h1UcLWukGe8zWtGlDxPwACZIZixYP3AHiMDUSSHqQSwRtYLUFr5Wye0SEDbPd2
2KPVAkoX4YxOeyE5uDTGPRCKWC/DdCjt7INzXWvP/kUeFy541aiSd0bZ82PH2WNY
73krUFZM2NHHqXiN0VdhzVDeI9MoVX8Pm8lk5SotXWxH7Y6iVqllG98X83X/OKMA
yajsgN8t2oe12OZFMf18MUHO1EBq9ZJzZQTLEDgI5Egr8Pcx46RWH/3FlScCEFoF
YwIDAQAB
-----END PUBLIC KEY-----''');

    digest = AcmeUtils.getDigest(key);
    expect(digest, 'UHnliA-nHylv8CpsdY9XsuZyvKLyWTq-4QpKx8V62H4');
  });
}
