// Conditional package imports avoid analyzer false positives for the IO target.
// ignore_for_file: prefer_relative_imports

import 'package:acme_client/src/acme_dns_resolver_udp_stub.dart'
    if (dart.library.io) 'package:acme_client/src/acme_dns_resolver_udp_io.dart';
import 'package:basic_utils/basic_utils.dart';

/// Resolves DNS TXT records for ACME DNS self-tests.
///
/// Production callers can usually use the default Google resolver. Local
/// integration tests can configure `AcmeDnsResolver.challtestsrv` to point at
/// Pebble's local test DNS server.
class AcmeDnsResolver {
  /// Uses Google Public DNS over HTTPS for TXT lookups.
  ///
  /// This is the default resolver used by `AcmeConnection`. It is suitable for
  /// checking whether a DNS challenge proof has propagated to public DNS before
  /// asking the CA to validate the challenge.
  const AcmeDnsResolver.google()
    : _provider = DnsApiProvider.GOOGLE,
      _host = null,
      _port = null,
      _timeout = null;

  /// Uses Cloudflare DNS over HTTPS for TXT lookups.
  ///
  /// This is an alternative public resolver for callers who prefer Cloudflare's
  /// DNS-over-HTTPS endpoint for challenge self-tests.
  const AcmeDnsResolver.cloudflare()
    : _provider = DnsApiProvider.CLOUDFLARE,
      _host = null,
      _port = null,
      _timeout = null;

  /// Uses a UDP DNS server for TXT lookups.
  ///
  /// This is mainly intended for local integration tests, for example querying
  /// a DNS server running inside a test harness. UDP DNS lookups require
  /// `dart:io`; on platforms without `dart:io`, calling [lookupTxt] with this
  /// resolver throws [UnsupportedError].
  const AcmeDnsResolver.udp({
    required String host,
    int port = 53,
    Duration timeout = const Duration(seconds: 5),
  }) : _provider = null,
       _host = host,
       _port = port,
       _timeout = timeout;

  /// Uses Pebble's `challtestsrv` DNS defaults for TXT lookups.
  ///
  /// The default endpoint is `localhost:8053`, matching the local Pebble
  /// harness in `tool/pebble/docker-compose.yml`. Override [host] or [port] if
  /// your harness exposes `challtestsrv` elsewhere. Like `udp`, this resolver
  /// requires `dart:io` when `lookupTxt` is called.
  const AcmeDnsResolver.challtestsrv({
    String host = 'localhost',
    int port = 8053,
    Duration timeout = const Duration(seconds: 5),
  }) : this.udp(host: host, port: port, timeout: timeout);

  final DnsApiProvider? _provider;
  final String? _host;
  final int? _port;
  final Duration? _timeout;

  Future<List<String>> lookupTxt(String name) async {
    final provider = _provider;
    if (provider != null) {
      final records = await DnsUtils.lookupRecord(
        name,
        RRecordType.TXT,
        provider: provider,
      );
      return records?.map((record) => record.data).toList() ?? const [];
    }

    return acmeLookupUdpTxt(
      name,
      host: _host!,
      port: _port!,
      timeout: _timeout!,
    );
  }
}
