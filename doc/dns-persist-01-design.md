# dns-persist-01 Design Notes

## Scope

This document sketches the changes needed to add support for the ACME
`dns-persist-01` challenge to `acme_client`.

It is intentionally a design note rather than a line-by-line implementation
plan.

## Current State

The client already supports:

- account bootstrap and directory discovery
- order creation and polling
- challenge authorization fetch
- `http-01` and `dns-01` data generation
- challenge validation

Relevant code:

- [lib/src/acme_client.dart](/home/bsutton/git/Dart-Acme-Client/lib/src/acme_client.dart)
- [lib/src/model/authorization.dart](/home/bsutton/git/Dart-Acme-Client/lib/src/model/authorization.dart)
- [lib/src/model/challenge.dart](/home/bsutton/git/Dart-Acme-Client/lib/src/model/challenge.dart)
- [lib/src/model/order.dart](/home/bsutton/git/Dart-Acme-Client/lib/src/model/order.dart)
- [lib/src/model/dns_dcv_data.dart](/home/bsutton/git/Dart-Acme-Client/lib/src/model/dns_dcv_data.dart)
- [lib/src/model/http_dcv_data.dart](/home/bsutton/git/Dart-Acme-Client/lib/src/model/http_dcv_data.dart)

The current protocol model is still shaped around simpler ACME v2 flows:

- `validate()` assumes key-authorization based challenge responses
- there is no model for `dns-persist-01`
- there is no first-class payload type for challenge responses

## dns-persist-01 Summary

The current draft defines a new challenge type: `dns-persist-01`.

Unlike `dns-01`, the proof is not a hash of key authorization placed at
`_acme-challenge.<fqdn>`.

Instead, the client or user publishes a persistent TXT record at:

- `_validation-persist.<fqdn>`

The TXT value contains:

- an issuer domain name chosen from the challenge's `issuer-domain-names`
- `accounturi=<account-url>`
- optional `policy=<value>`
- optional `persistUntil=<unix timestamp>`

This makes the validation record reusable and strongly bound to the ACME
account.

## Why This Belongs In acme_client

`dns-persist-01` is ACME protocol support, so it belongs in `acme_client`.

`acme_client` should:

- parse the challenge object
- expose the exact TXT record name and value to publish
- submit and poll the ACME challenge
- provide a simple CLI tool or helper command that prints the TXT record the
  user must publish before continuing

`acme_client` should not:

- integrate directly with Route53, Cloudflare, or other DNS providers
- write DNS records itself

That keeps the package generic and reusable while still making the workflow
practical for users.

## API Direction

The public API should stay provider-agnostic and additive.

The API should avoid raw `Map<String, dynamic>` inputs where a dedicated model
would be clearer.

Possible usage:

```dart
final order = await client.order(
  Order(
    identifiers: [Identifiers(type: 'dns', value: 'example.com')],
  ),
);

final authorizations = await client.getAuthorization(order);
final auth = authorizations.first;

final persistData = client.buildDnsPersistData(
  auth,
  issuerDomainName: 'authority.example',
  policy: 'wildcard',
  persistUntil: DateTime.utc(2026, 12, 31),
);

// Caller provisions:
// _validation-persist.example.com TXT "authority.example; accounturi=https://ca.example/acct/123; policy=wildcard"

await client.validate(
  persistData.challenge,
  response: persistData.validationResponse,
);
```

## Proposed Model Changes

### 1. Add a validation constant

In `lib/src/constants.dart`:

```dart
final String VALIDATION_DNS_PERSIST = 'dns-persist-01';
```

### 2. Expand `Challenge`

`Challenge` currently models:

- `type`
- `url`
- `token`
- `authorizationUrl`
- `error`

It should also model:

- `status`
- `issuerDomainNames`

Suggested shape:

```dart
class Challenge {
  String? type;
  String? url;
  String? token;
  String? status;
  String? authorizationUrl;
  List<String>? issuerDomainNames;
  ChallengeError? error;
}
```

Notes:

- `issuerDomainNames` should map to the JSON field `issuer-domain-names`
- malformed `dns-persist-01` challenges should be rejected early if the field
  is absent or empty

### 3. Add `DnsPersistDcvData`

Do not overload `DnsDcvData`.

`dns-01` and `dns-persist-01` are materially different:

- different DNS label
- different TXT content
- different semantics

Add a new model, for example:

```dart
class DnsPersistDcvData extends DcvData {
  String recordName;
  String recordValue;
  String issuerDomainName;
  String accountUri;
  String? policy;
  DateTime? persistUntil;
  Challenge challenge;
}
```

This keeps `DnsDcvData` focused on `_acme-challenge` records and avoids
branching everywhere.

### 4. Add a challenge response model

Do not model the validation response as a generic map.

Instead, introduce a parent response type and concrete subclasses, for example:

```dart
abstract class ChallengeResponsePayload {}

class KeyAuthorizationChallengeResponse extends ChallengeResponsePayload {
  String keyAuthorization;
}

class DnsPersistChallengeResponse extends ChallengeResponsePayload {
  String issuerDomainName;
  String accountUri;
  String? policy;
  DateTime? persistUntil;
}
```

This keeps the API strongly typed and avoids passing opaque data structures
through `validate()`.

### 5. Keep account binding in `AcmeClient`

The record value requires `accounturi=<account-url>`.

That information belongs to the active ACME account, which already lives on
`AcmeClient`. The caller should not supply `accounturi` manually; the client
should derive it from the account URL returned by the ACME server.

Because of that, prefer a client-level builder rather than pushing the entire
responsibility into `Authorization`.

Suggested method:

```dart
DnsPersistDcvData buildDnsPersistData(
  Authorization authorization, {
  String? issuerDomainName,
  String? policy,
  DateTime? persistUntil,
})
```

This method should:

- locate the `dns-persist-01` challenge
- validate that `issuerDomainNames` is present and non-empty
- select an issuer domain name
- build `_validation-persist.<identifier>`
- format the TXT record value
- attach the original challenge object

## Validation Flow Changes

## Problem

`validate()` is currently hard-wired to send:

```dart
{
  'keyAuthorization': '${challenge.token}.${thumbprint}'
}
```

That works for current challenge types, but it assumes every challenge is
key-authorization based.

## Proposed Refactor

Refactor `validate()` so that payload selection is challenge-type aware.

Suggested direction:

```dart
Future<ChallengeValidationResult> validate(
  Challenge challenge, {
  int maxAttempts = 15,
  ChallengeResponsePayload? response,
})
```

Internal behaviour:

- `http-01`: use the current key-authorization payload model
- `dns-01`: use the current key-authorization payload model
- `dns-persist-01`: use a dedicated `DnsPersistChallengeResponse`
- unknown types: throw a protocol-specific client exception

If the draft or server implementation uses an empty response body or different
challenge response fields, that decision should be encoded here rather than
scattered through callers.

## Order and Authorization Convenience

These are optional, but useful:

- `Authorization.getChallengeByTypeOrNull(String type)`
- `Authorization.hasChallengeType(String type)`
- `AcmeClient.pendingAuthorizations(Order order)`

Avoid embedding too much protocol logic into the JSON model classes. The thin
model should stay easy to serialize and test.

## Challenge Error Extraction

The package should have one internal helper responsible for extracting the most
useful message from an ACME error body.

For example, when `response.data['challenges'][0]['error']['detail']` exists,
surface it directly.

That gives callers errors such as:

- `Challenge validation failed: 34.69.220.126: Fetching http://...: Timeout during connect`

instead of:

- `false`
- `null`
- or a generic `invalid`

## Migration Strategy

Do this in stages.

### Stage 1

- add `ChallengeValidationResult`
- add a typed `ChallengeResponsePayload` hierarchy
- make `validate()` challenge-type aware

### Stage 2

- add `dns-persist-01` models and builders
- add CLI/helper output for the TXT record a user must publish

### Stage 3

- add unit tests
- add integration tests against a supporting ACME test server

This keeps the protocol refactor manageable and avoids introducing
`dns-persist-01` on top of an API that is too loosely typed.

## Testing Plan

### Unit tests

- parse `issuer-domain-names`
- reject malformed `dns-persist-01` challenge objects
- generate `_validation-persist.<fqdn>` record names
- generate TXT values with `accounturi`
- include optional `policy`
- include optional `persistUntil`
- validate wildcard policy handling
- convert nested ACME error bodies into clear client exceptions

### Integration tests

- validate `dns-01` and `http-01` continue to work unchanged
- add `dns-persist-01` integration tests once the selected test server supports
  it
- verify error details are surfaced for failed validations, including timeout
  and authorization failures

## Open Questions

1. Does the target ACME test server expose `dns-persist-01` today?
   Current assumption: only Pebble is supported in the near term.
2. Should `validate()` remain bool-like for backward compatibility, or is a
   breaking change acceptable?
   Current answer: a breaking change is acceptable if it gives the caller a
   better result.
3. Should `accounturi` be exposed directly in `DnsPersistDcvData`, or should
   callers treat the TXT value as opaque?
   The client must supply it. The draft says the TXT issue-value MUST contain
   an `accounturi` parameter whose value identifies the ACME account making the
   request. That means `accounturi` should be derived from the active account
   on `AcmeClient`, not entered manually by the user. The user may still need
   to manually publish the TXT record, so the CLI/helper should print the fully
   constructed record including `accounturi`, but the API should treat that
   field as generated rather than caller-provided.
4. Do we want wildcard policy support in the first implementation, or should
   initial support only cover the base record format?
   Current answer: include wildcard support in the first implementation.

## Recommendation

The best order of work is:

1. refactor `validate()` so it is challenge-type aware
2. add typed challenge-response payload classes
3. add `dns-persist-01` data modeling and builders
4. add integration coverage once a server with real support is confirmed

## References

- dns-persist-01 draft: https://datatracker.ietf.org/doc/html/draft-ietf-acme-dns-persist
- Boulder release note mentioning challtestsrv updates for `dns-persist-01`: https://newreleases.io/project/github/letsencrypt/boulder/release/v0.20260303.0
