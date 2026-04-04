# Dart Acme Client

An ACME V2 compatible client written in Dart.

## Table of Contents

- [Dart Acme Client](#dart-acme-client)
  - [Table of Contents](#table-of-contents)
  - [Preamble](#preamble)
  - [Install](#install)
    - [pubspec.yaml](#pubspecyaml)
  - [Import](#import)
  - [Acme Client](#acme-client)
    - [Client Setup](#client-setup)
  - [Applying for Certificate Issuance](#applying-for-certificate-issuance)
    - [Place Order](#place-order)
    - [Fetch Authorization Data](#fetch-authorization-data)
    - [Get Challenge For Authorization](#get-challenge-for-authorization)
    - [dns-persist-01](#dns-persist-01)
    - [Self Test](#self-test)
    - [Trigger Validation](#trigger-validation)
    - [Finalize Order](#finalize-order)
    - [Fetch Certificate](#fetch-certificate)
  - [Changelog](#changelog)
  - [Copyright and license](#copyright-and-license)

## Preamble

As this package is written in pure [Dart](https://dart.dev), it can be used on all [platforms](https://dart.dev/platforms) on which dart is currently running. This includes the use of frameworks like [Flutter](https://flutter.dev), [Angular Dart](https://angulardart.dev) and many more. This package can also be used for command line tools or rest services compiled with [dart2native](https://dart.dev/tools/dart2native).

**Note:** Feel free to contribute by creating pull requests or file an issue for bugs, questions and feature requests.

## Install

### pubspec.yaml

Update pubspec.yaml and add the following line to your dependencies.

```yaml
dependencies:
  acme_client: ^1.3.0
```

## Import

Import the package with :

```dart
import 'package:acme_client/acme_client.dart';
```

## Acme Connection

This is a simple ACME written in Dart based on the [RFC 8555](https://datatracker.ietf.org/doc/html/rfc8555). The client should be able to communicate with every ACME server that is based on the mentioned RFC including **Let's Encrypt**.

### Connection Setup

Create an `AcmeConnection` and either generate fresh
`AcmeAccountCredentials` or restore previously persisted credentials.

```dart
  const connection = AcmeConnection(
    baseUrl: 'https://acme-server.com',
  );

  final credentials = AcmeAccountCredentials.generate(
    acceptTerms: true,
    contacts: ['mailto:jon@doe.com'],
  );
```

- `AcmeConnection.baseUrl` = The ACME directory URL, such as Pebble's `https://localhost:14000/dir`.
- `AcmeConnection.dio` = Optional advanced transport override. Most production callers should not pass this. It is mainly useful for tests or special environments such as local Pebble, custom TLS trust, or proxies.
- `AcmeAccountCredentials.privateKeyPem` = The private key in PEM format.
- `AcmeAccountCredentials.publicKeyPem` = The public key in PEM format.
- `AcmeAccountCredentials.acceptTerms` = Accept terms and condition while creating / fetching an account.
- `AcmeAccountCredentials.contacts` = A list of email addresses. Each address should have the format `mailto:jon@doe.com`.

If you already persisted credentials, restore them with:

```dart
  final credentials = AcmeAccountCredentials.fromJson(jsonString);
```

If you are using the default Let's Encrypt production endpoint, you can omit the
connection argument entirely.

Standard connection presets are available for common cases:

```dart
  const production = AcmeConnection.production;
  const staging = AcmeConnection.staging;
```

Fetch the existing account:

```dart
  var account = await Account.fetch(credentials);
```

To force creation of a new account instead of looking up an existing one:

```dart
  var account = await Account.create(credentials);
```

To persist the account identity inputs needed to resume later operations such as
renewals, round-trip `AcmeAccountCredentials`:

```dart
  final jsonString = credentials.toJson(pretty: true);

  // Persist `jsonString`, then later restore it.
  final restoredCredentials = AcmeAccountCredentials.fromJson(jsonString);
  final restoredAccount = await Account.fetch(
    restoredCredentials,
    connection: connection,
  );
```

If you already have an attached `Account`, you can derive the same credentials:

```dart
  final credentials = account.toAccountCredentials();
```

## Applying for Certificate Issuance

### Place Order

Placing an order can be done by creating a new order object and adding the identifiers that should be placed in the certificate. The account then creates the order and returns the order information from the ACME server.

```dart
  var order = Order(
    identifiers: [DomainIdentifier('example.com')]
  );
  var newOrder = await account.createOrder(order);
```

### Fetch Authorization Data

For each order, the ACME server returns authorization data for each identifier when requested via **Order.getAuthorizations()**.

```dart
  var auth = await newOrder.getAuthorizations();
```

### Get Challenge For Authorization

For each returned authorization there are multiple challenges. You can use one of these challenges to prove controll over one identifier and fulfill the authorization request.

```dart
  for(var a in auth){
     var challenge = Challenge.get<HttpChallenge>(a.challenges!);
     var data = challenge.buildChallengeData(
       domainIdentifier: a.identifier! as DomainIdentifier,
       publicKeyPem: credentials.publicKeyPem,
     );
  }

  for(var a in auth){
     var challenge = Challenge.get<DnsChallenge>(a.challenges!);
     var data = challenge.buildChallengeData(
       domainIdentifier: a.identifier! as DomainIdentifier,
       publicKeyPem: credentials.publicKeyPem,
     );
  }
```

### dns-persist-01

If the ACME server offers `dns-persist-01`, fetch the authorizations for the
order, ask the order for the concrete `DnsPersistChallenge`, and then build the
TXT record from that challenge.

```dart
  var authorizations = await newOrder.getAuthorizations();
  var domainIdentifier = DomainIdentifier('example.com');
  var challenge = newOrder.getChallengeForIdentifier<DnsPersistChallenge>(
    domainIdentifier,
    authorizations,
  );
  var persistData = challenge.buildDnsPersistChallengeData(
    domainIdentifier: domainIdentifier,
    accountUri: account.accountURL!,
    issuerDomainName: 'ca.example',
  );

  print(persistData.toBindString());
```

The returned `DnsPersistChallengeData` contains the TXT record to publish at
`_validation-persist.<fqdn>`.

### Self Test

It is recommended to check in advance if a challenge is passed by using the appropriate client method. Via the maxAttempts parameter you can increase or decrease the amount of time it will try to check for the challenge token. The default is 15.

**Note**: The DNS self test uses the Google DNS Rest API to fetch the resource records.

```dart
  var self = await account.selfDNSTest(data); // DnsChallengeData
  if (!self) {
    print('Selftest failed, no DNS record found');
  }

  var self = await account.selfHttpTest(data); // HttpChallengeData
  if (!self) {
    print('Selftest failed, no file found or content missmatch');
  }
```

There is no generic public self-test helper for `dns-persist-01`. The normal
flow is to print `persistData.toBindString()`, publish it in DNS, wait until it
is visible to the CA, and then call `validate(persistData.challenge)`.

### Trigger Validation

To tell the ACME server to check the challenge, call `validate()` on the
account with the desired challenge. This will trigger the validation and check
every 4 seconds the status of the authorization to change to "valid".
Via the maxAttempts parameter you can increase or decrease the amount of time it will poll the status. The default is 15.

```dart
  var data; // HttpChallengeData or DnsChallengeData
  var authValid = await account.validate(data.challenge);
  if (!authValid) {
    print('Authorization failed, exit');
  }
```

### Finalize Order

If every authorization has the status "valid", check that the order is ready and then finalize it by sending a CSR to the ACME server. The CSR is automatically formatted according to the RFC rules (base64Url encoded without headers).

```dart
var ready = await newOrder.isReady();
if (!ready) {
  print('Order is not ready');
}
```

```dart
var finalOrder = await newOrder.finalize(csr);
```

### Fetch Certificate

A list of certificates can then be fetched directly from the finalized order.

```dart
var certs = await finalOrder.getCertificates();
```

## Changelog

## Pebble Integration

For local integration testing with Pebble and `challtestsrv`, see
[tool/pebble/README.md](tool/pebble/README.md). The repository includes:

- a local Docker Compose harness
- a Pebble config file
- an end-to-end `dns-persist-01` test in
  [test/dns_persist_pebble_test.dart](test/dns_persist_pebble_test.dart)

For a detailed changelog, see the [CHANGELOG.md](CHANGELOG.md) file

## Copyright and license

MIT License

Copyright (c) 2021 Ephenodrom

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
