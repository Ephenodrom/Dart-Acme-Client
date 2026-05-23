Future<List<String>> acmeLookupUdpTxt(
  String name, {
  required String host,
  required int port,
  required Duration timeout,
}) {
  throw UnsupportedError('UDP DNS lookups require dart:io support');
}
