import 'dart:convert';
import 'dart:io';

import 'package:acme_client/src/AcmeClient.dart';
import 'package:acme_client/src/Constants.dart';
import 'package:acme_client/src/model/Identifiers.dart';
import 'package:acme_client/src/model/Order.dart';
import 'package:basic_utils/basic_utils.dart';

void main(List<String> args) async {
  var privateKeyPem =
      '''-----BEGIN RSA PRIVATE KEY----- ... -----END RSA PRIVATE KEY-----''';

  var publicKeyPem =
      '''-----BEGIN PUBLIC KEY----- ... -----END PUBLIC KEY-----''';

  var csr =
      '''-----BEGIN CERTIFICATE REQUEST----- ... -----END CERTIFICATE REQUEST-----''';

  var cn = 'foobar.com';

  var client = AcmeClient(
    'https://acme-staging-v02.api.letsencrypt.org',
    privateKeyPem,
    publicKeyPem,
    true,
    ['mailto:jon@doe.com'],
  );
  await client.init();

  var order = Order();
  var identifier = Identifiers(type: 'dns', value: cn);
  order.identifiers = [identifier];
  print('Order certificate for $cn');
  var newOrder = await client.order(order);

  print('Fetch authorization data for order');
  var auth = await client.getAuthorization(newOrder!);
  print('Place the following DNS record in the corresponding zone file:');
  print(DnsUtils.toBind(auth!.first.getDnsDcvData().rRecord));
  print('Press any key if you are ready to trigger the challenge check');
  stdin.readLineSync(encoding: utf8);

  var self = await client.selfDNSTest(auth.first.getDnsDcvData());
  if (!self) {
    print('Selftest failed, no DNS record found');
    exit(0);
  }

  var authValid = await client.validate(auth.first.challenges!
      .firstWhere((element) => element.type == VALIDATION_DNS));

  if (!authValid) {
    print('Authorization failed, exit');
    exit(0);
  }
  print('Authorization successfull, finalize order');
  await Future.delayed(Duration(seconds: 1));
  var ready = await client.isReady(newOrder);
  if (!ready) {
    print('Order is not ready ...');
    exit(0);
  }
  print('Order is ready, finalize order');

  var persistent = await client.finalizeOrder(newOrder, csr);

  var certs = await client.getCertificate(persistent!);
  print(certs);
}
