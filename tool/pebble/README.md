# Pebble Harness

This directory contains a local Pebble + `challtestsrv` setup for integration
testing `http-01`, `dns-01`, and `dns-persist-01`.

## Start the harness

```sh
docker compose -f tool/pebble/docker-compose.yml up -d
```

The ACME directory endpoint will be available at:

```text
https://localhost:14000/dir
```

The `challtestsrv` management API will be available at:

```text
http://localhost:8055
```

## Run the integration test

Create an untracked local config file with the Pebble account key pair:

```sh
cp tool/pebble/pebble-test.example.json tool/pebble/pebble-test.local.json
```

```sh
export ACME_PEBBLE_ENABLE_TESTS=true
export ACME_PEBBLE_BASE_URL=https://localhost:14000/dir
export ACME_PEBBLE_MANAGEMENT_URL=http://localhost:8055
export ACME_PEBBLE_CONFIG_PATH=tool/pebble/pebble-test.local.json
dart test test/pebble_integration_test.dart
```

If you prefer to trust Pebble's root certificate instead of allowing insecure
TLS in the test, retrieve the root from Pebble's management API and point the
test at it:

```sh
curl -k https://localhost:15000/roots/0 -o /tmp/pebble-root.pem
export ACME_PEBBLE_TRUSTED_ROOT=/tmp/pebble-root.pem
dart test test/pebble_integration_test.dart
```

## Notes

- Pebble's official directory endpoint is `/dir`, not `/directory`.
- The integration test publishes DNS and HTTP challenge state through the
  `challtestsrv` management API.
- `tool/pebble/pebble-test.local.json` is ignored by git and is the intended
  place for local Pebble test credentials.
