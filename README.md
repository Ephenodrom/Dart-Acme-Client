# Dart Acme Client

An ACME V2 compatible client written in Dart.

## Table of Contents

1. [Preamble](#preamble)
2. [Install](#install)
   * [pubspec.yaml](#pubspec.yaml)
3. [Import](#import)
4. [Acme Client](#acme-client)
   * [Client Setup](#client-setup)
5. [Applying for Certificate Issuance](#applying-for-certificate-issuance)
   * [Place Prder](#client-setup)
   * [Fetch Authorization Data](#fetch-authorization-data)
   * [Get Challenge For Authorization](#get-challange-for-authorization)
   * [Self Test](#self-test)
   * [Trigger Validation](#trigger-validation)
   * [Finalize Order](#finalize-order)
   * [Fetch Certificate](#fetch-certificate)
6. [Changelog](#changelog)
7. [Copyright and license](#copyright-and-license)

## Preamble

As this package is written in pure [Dart](https://dart.dev), it can be used on all [platforms](https://dart.dev/platforms) on which dart is currently running. This includes the use of frameworks like [Flutter](https://flutter.dev), [Angular Dart](https://angulardart.dev) and many more. This package can also be used for command line tools or rest services compiled with [dart2native](https://dart.dev/tools/dart2native).

**Note:** Feel free to contribute by creating pull requests or file an issue for bugs, questions and feature requests.

## Install

### pubspec.yaml

Update pubspec.yaml and add the following line to your dependencies.

```yaml
dependencies:
  acme_client: ^1.1.0
```

## Import

Import the package with :

```dart
import 'package:acme_client/acme_client.dart';
```

## Acme Client

This is a simple ACME written in Dart based on the [RFC 8555](https://datatracker.ietf.org/doc/html/rfc8555). The client should be able to communicate with every ACME server that is based on the mentioned RFC including **Let's Encrypt**.

### Client Setup

Create a new client by calling the constructor and pass the appropriate parameters.

```dart
  var client = AcmeClient(
    'https://acme-server.com',
    privateKeyPem,
    publicKeyPem,
    true,
    ['mailto:jon@doe.com'],
  );
```

* baseUrl = The base url of the acme server.
* privateKeyPem = The private key in PEM format.
* publicKeyPem  = The public key in PEM format.
* acceptTerms = Accept terms and condition while creating / fetching an account.
* contacts = A list of email addresses. Each address should have the format 'mailto:jon@doe.com'.

**Note**: If you want to create a RSA/ECC key pair with Dart, take a look at the [Basic Utils](https://github.com/Ephenodrom/Dart-Basic-Utils) Package. The X509Utils and CryptoUtils, contain everything needed for creating a key pair and formating it to PEM.

After the client is setup, call the **init()** method, to fetch the directories and account information from the server. If there is no account for the given public key on the server, the client will create a new account.

```dart
  await client.init();
```

## Applying for Certificate Issuance

### Place Order

Placing an order can be done by creating a new order object and adding the identifiers that should be placed in the certificate. The order methode of the client will then return the order information returned by the acme server.

```dart
  var order = Order(
    identifiers: [Identifiers(type: 'dns', value: 'example.com')]
  );
  var newOrder = await client.order(order);
```

### Fetch Authorization Data

For each order, the ACME server return an authorization data for each identifier if requested via the **getAuthorization()** method..

```dart
  var auth = await client.getAuthorization(newOrder!);
```

### Get Challenge For Authorization

For each returned authorization there are multiple challenges. You can use one of these challenges to prove controll over one identifier and fulfill the authorization request.

```dart
  for(var a in auth){
     var data = a.getHttpDcvData();
  }

  for(var a in auth){
     var data = a.getDnsDcvData();
  }
```

### Self Test

It is recommended to check in advance if a challenge is passed by using the appropriate client method. Via the maxAttempts parameter you can increase or decrease the amount of time it will try to check for the challenge token. The default is 15.

**Note**: The DNS self test uses the Google DNS Rest API to fetch the resource records.

```dart
  var self = await client.selfDNSTest(data); // DnsDcvData
  if (!self) {
    print('Selftest failed, no DNS record found');
  }

  var self = await client.selfHttpTest(data); // HttpDcvData
  if (!self) {
    print('Selftest failed, no file found or content missmatch');
  }
```

### Trigger Validation

To tell the ACME server to check the challenge, call the validate() method on the client with the desired challenge. This will trigger the validation and check every 4 seconds the status of the authorization to change to "valid".
Via the maxAttempts parameter you can increase or decrease the amount of time it will poll the status. The default is 15.

```dart
  var data; // HttpDcvData or DnsDcvData
  var authValid = await client.validate(data.challenge);
  if (!authValid) {
    print('Authorization failed, exit');
  }
```

### Finalize Order

If every authorization has the status "valid" finalize the order by sending a CSR to acme server. The CSR will automatically formated according to the RFC rules (base64Url encoded without headers).

```dart
var finalOrder = await client.finalizeOrder(newOrder, csr);
```

### Fetch Certificate

A list of certificates can then be fetched via the **getCertificate()** method by passing the finalized order object.

```dart
var certs = await client.getCertificate(finalOrder);
```

## Changelog

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
