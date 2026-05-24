import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:acme_client/acme_client.dart';
import 'package:test/test.dart';

void main() {
  test('UDP resolver reads TXT records from a local DNS server', () async {
    final server = await _FakeDnsServer.start(
      records: const {
        '_acme-challenge.example.com': ['proof-value'],
      },
    );
    addTearDown(server.close);

    final resolver = AcmeDnsResolver.udp(
      host: 'localhost',
      port: server.port,
      timeout: const Duration(seconds: 1),
    );

    final records = await resolver.lookupTxt('_acme-challenge.example.com');

    expect(records, ['proof-value']);
  });

  test('challtestsrv resolver uses the local Pebble DNS defaults', () async {
    final server = await _FakeDnsServer.start(
      records: const {
        '_acme-challenge.example.com': ['proof-value'],
      },
    );
    addTearDown(server.close);

    final resolver = AcmeDnsResolver.challtestsrv(
      port: server.port,
      timeout: const Duration(seconds: 1),
    );

    final records = await resolver.lookupTxt('_acme-challenge.example.com');

    expect(records, ['proof-value']);
  });
}

class _FakeDnsServer {
  _FakeDnsServer._(this._socket, this._records) {
    _subscription = _socket.listen(_handleEvent);
  }

  static Future<_FakeDnsServer> start({
    required Map<String, List<String>> records,
  }) async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    return _FakeDnsServer._(socket, records);
  }

  final RawDatagramSocket _socket;
  final Map<String, List<String>> _records;
  late final StreamSubscription<RawSocketEvent> _subscription;

  int get port => _socket.port;

  Future<void> close() async {
    await _subscription.cancel();
    _socket.close();
  }

  void _handleEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) {
      return;
    }

    Datagram? datagram;
    while ((datagram = _socket.receive()) != null) {
      final request = datagram!.data;
      final question = _parseQuestion(request);
      final values = _records[question.name] ?? const [];
      final response = _buildResponse(
        request,
        questionEnd: question.endOffset,
        values: values,
      );
      _socket.send(response, datagram.address, datagram.port);
    }
  }
}

_DnsQuestion _parseQuestion(Uint8List request) {
  var offset = 12;
  final labels = <String>[];
  while (request[offset] != 0) {
    final length = request[offset];
    offset++;
    labels.add(ascii.decode(request.sublist(offset, offset + length)));
    offset += length;
  }
  offset++;
  return _DnsQuestion(labels.join('.'), offset + 4);
}

Uint8List _buildResponse(
  Uint8List request, {
  required int questionEnd,
  required List<String> values,
}) {
  final question = request.sublist(12, questionEnd);
  final builder = BytesBuilder()
    ..add([
      request[0],
      request[1],
      0x81,
      0x80,
      0x00,
      0x01,
      values.length >> 8,
      values.length & 0xff,
      0x00,
      0x00,
      0x00,
      0x00,
    ])
    ..add(question);

  for (final value in values) {
    final valueBytes = utf8.encode(value);
    builder
      ..add([
        0xc0,
        0x0c,
        0x00,
        0x10,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x00,
        0x00,
        valueBytes.length + 1,
        valueBytes.length,
      ])
      ..add(valueBytes);
  }

  return builder.toBytes();
}

class _DnsQuestion {
  const _DnsQuestion(this.name, this.endOffset);

  final String name;
  final int endOffset;
}
