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
- `AcmeConnection(..., dio: ...)` = Optional advanced transport override. Most production callers should not pass this. It is mainly useful for tests or special environments such as local Pebble, custom TLS trust, or proxies.
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
  const pebble = AcmeConnection.pebble();
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

### Credential Storage

Store the private key outside your repository. This file identifies the ACME
account, so it should be treated as a secret and restricted to the process or
user that needs it.

- Linux: store it under a per-user config path such as `~/.config/acme_client/account-credentials.json` with restrictive permissions like `0600`, owned by the service user.
- macOS: prefer Keychain if you already use it, otherwise store the file under the user's home directory with user-only permissions.
- Windows: prefer DPAPI or Credential Manager if available, otherwise store the file under `%APPDATA%` with user-only ACLs.
- Containers and servers: mount the credentials from a secret store or locked-down config volume rather than baking them into the image or repository.
- Source control: never commit the ACME private key or embed it in source files, examples, or checked-in test fixtures.

For a complete load-or-create example, see
`example/fetch_account_example.dart`.

If you already have an attached `Account`, you can derive the same credentials:

```dart
  final credentials = account.toAccountCredentials();
```

### Certificate Credentials

Certificate issuance uses a separate keypair from the ACME account keypair.
`CertificateCredentials` packages the certificate private key, public key, and
CSR for a specific certificate request.

```dart
  final certificateCredentials = CertificateCredentials.generate(
    identifiers: [DomainIdentifier('example.com')],
  );
```

- `CertificateCredentials.privateKeyPem` = The certificate private key in PEM format.
- `CertificateCredentials.publicKeyPem` = The certificate public key in PEM format.
- `CertificateCredentials.csrPem` = The CSR in PEM format for finalizing the ACME order.
- `CertificateCredentials.identifiers` = The DNS names encoded into the CSR.

Persist certificate credentials the same way you persist account credentials:
outside the repository, with restrictive permissions. For a complete
load-or-create example, see `example/certificate_credentials_example.dart`.

## Applying for Certificate Issuance

### Place Order

Placing an order is done by asking the account for the challenge workflow you
want to use and passing the list of domain identifiers.

```dart
  var newOrder = await account.createOrderForHttp(
    identifiers: [DomainIdentifier('example.com')],
  );
```

### Fetch Authorization Data

To inspect what challenge types the CA offers for a given identifier, use the
separate discovery API.

```dart
  var availableChallenges = await account.discoverAvailableChallenges(
    identifier: DomainIdentifier('example.com'),
  );
```

For a complete discovery workflow, see
`example/discovery_example.dart`.

### Get Challenge For Authorization

For each returned authorization there are multiple challenges. You can use one of these challenges to prove controll over one identifier and fulfill the authorization request.

```dart
  var httpOrder = await account.createOrderForHttp(
    identifiers: [DomainIdentifier('example.com')],
  );
  var httpAuthorization = await httpOrder.getAuthorization(
    DomainIdentifier('example.com'),
  );
  var httpChallenge = httpAuthorization.getChallenge();
  var httpProof = httpChallenge.buildProof();

  var dnsOrder = await account.createOrderForDns(
    identifiers: [DomainIdentifier('example.com')],
  );
  var dnsAuthorization = await dnsOrder.getAuthorization(
    DomainIdentifier('example.com'),
  );
  var dnsChallenge = dnsAuthorization.getChallenge();
  var dnsProof = dnsChallenge.buildProof();
```

Complete typed examples are available in:

- `example/http_challenge_example.dart`
- `example/dns_challenge_example.dart`
- `example/dns_persist_example.dart`
- `example/http_renewal_example.dart`
- `example/dns_renewal_example.dart`
- `example/dns_persist_renewal_example.dart`

### dns-persist-01

If the ACME server offers `dns-persist-01`, fetch the authorizations for the
order, ask the order for the concrete `DnsPersistChallenge`, and then build the
TXT record from that challenge.

```dart
  var order = await account.createOrderForDnsPersist(
    identifiers: [DomainIdentifier('example.com')],
  );
  var domainIdentifier = DomainIdentifier('example.com');
  var authorization = await order.getAuthorization(domainIdentifier);
  var challenge = authorization.getChallenge();
  var persistProof = challenge.buildProof();

  print(persistProof.toBindString());
```

The returned `DnsPersistChallengeProof` contains the TXT record to publish at
`_validation-persist.<fqdn>`.

### Self Test

It is recommended to check in advance that the published proof is publicly
visible before asking the CA to validate it. Call `selfTest()` on the
challenge. Via the `maxAttempts` parameter you can increase or decrease the
amount of time it will try to observe the proof. The default is 15.

`selfTest()` reuses the bound `AcmeConnection` only for shared HTTP client
configuration and logging. It does not contact the CA.

**Note**: The DNS self test uses the Google DNS Rest API to fetch the resource records.

```dart
  var self = await challenge.selfTest(); // DnsChallenge
  if (!self) {
    print('Selftest failed, no DNS record found');
  }

  var self = await challenge.selfTest(); // HttpChallenge
  if (!self) {
    print('Selftest failed, no file found or content missmatch');
  }
```

The same `challenge.selfTest()` flow also applies to `dns-persist-01`.

### Trigger Validation

To tell the ACME server to check the challenge, call `validate()` on the
challenge itself. This will trigger the validation and check every 4 seconds
for the authorization status to change to `valid`.
Via the maxAttempts parameter you can increase or decrease the amount of time it will poll the status. The default is 15.

```dart
  var authValid = await challenge.validate();
  if (!authValid) {
    print('Authorization failed, exit');
  }
```

### Finalize Order

If every authorization has the status `valid`, check that the order is ready
and then finalize it by sending the CSR from your `CertificateCredentials` to
the ACME server. The CSR is automatically formatted according to the RFC rules
(base64url encoded without headers).

```dart
var ready = await newOrder.isReady();
if (!ready) {
  print('Order is not ready');
}
```

```dart
final certificateCredentials = CertificateCredentials.generate(
  identifiers: [DomainIdentifier('example.com')],
);

await newOrder.finalize(certificateCredentials);
```

### Fetch Certificate

A list of certificates can then be fetched directly from the finalized order.

```dart
var certs = await newOrder.getCertificates();
```

### Renewals

For renewals, keep using the same `AcmeAccountCredentials`. That is your ACME
account identity and should normally be long-lived.

For `CertificateCredentials`, you have two valid choices:

- Reuse the same stored `CertificateCredentials` if you want the renewed certificate to keep the same private key.
- Generate new `CertificateCredentials` for the renewal if you want certificate key rotation.

In both cases, the CSR must match the identifiers on the renewal order. If the
set of names changes, generate new `CertificateCredentials` for that new set of
identifiers.

Renewal examples are available in:

- `example/http_renewal_example.dart`
- `example/dns_renewal_example.dart`
- `example/dns_persist_renewal_example.dart`

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
