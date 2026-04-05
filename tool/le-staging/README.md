# LE Staging System Test

This directory contains local configuration for the live Let's Encrypt staging
system test in [test/le_staging_system_test.dart](../../test/le_staging_system_test.dart).

## Setup

Create an untracked local config:

```sh
cp tool/le-staging/le-staging.example.yaml tool/le-staging/le-staging.local.yaml
```

Then edit `tool/le-staging/le-staging.local.yaml` and provide:

- `enabled: true`
- `contact`
- `dnsPersist.identifier`
- `dnsPersist.cloudflare.zoneName`
- `dnsPersist.cloudflare.apiToken`

Use a dedicated test hostname under a zone you control, for example
`acme-staging.squarephone.biz`.

## Run

```sh
dart test test/le_staging_system_test.dart -r expanded
```

The test file contains:

- a challenge inspection test that prints the raw `dns-persist-01` challenge
  object returned by Let's Encrypt staging
- a full `dns-persist-01` acquisition and renewal test that publishes the TXT
  record through the Cloudflare API
