import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

Future<List<String>> acmeLookupUdpTxt(
  String name, {
  required String host,
  required int port,
  required Duration timeout,
}) async {
  final addresses = await InternetAddress.lookup(host);
  for (final address in addresses) {
    final queryId = Random.secure().nextInt(0x10000);
    final query = _buildTxtQuery(name, queryId);
    final response = await _queryUdp(address, port, query, queryId, timeout);
    if (response != null) {
      return _parseTxtResponse(response);
    }
  }
  return const [];
}

Uint8List _buildTxtQuery(String name, int queryId) {
  final builder = BytesBuilder()
    ..add([
      queryId >> 8,
      queryId & 0xff,
      0x01,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
      0x00,
    ]);

  final normalized = name.endsWith('.')
      ? name.substring(0, name.length - 1)
      : name;
  for (final label in normalized.split('.')) {
    final labelBytes = ascii.encode(label);
    if (labelBytes.length > 63) {
      throw ArgumentError.value(
        name,
        'name',
        'DNS label is longer than 63 bytes',
      );
    }
    builder
      ..addByte(labelBytes.length)
      ..add(labelBytes);
  }
  builder.add([0x00, 0x00, 0x10, 0x00, 0x01]);
  return builder.toBytes();
}

Future<Uint8List?> _queryUdp(
  InternetAddress address,
  int port,
  Uint8List query,
  int queryId,
  Duration timeout,
) async {
  final socket = await RawDatagramSocket.bind(
    address.type == InternetAddressType.IPv6
        ? InternetAddress.anyIPv6
        : InternetAddress.anyIPv4,
    0,
  );
  final completer = Completer<Uint8List?>();
  late final StreamSubscription<RawSocketEvent> subscription;
  Timer? timer;

  void complete(Uint8List? value) {
    if (!completer.isCompleted) {
      completer.complete(value);
    }
  }

  subscription = socket.listen(
    (event) {
      if (event != RawSocketEvent.read) {
        return;
      }
      Datagram? datagram;
      while ((datagram = socket.receive()) != null) {
        final data = datagram!.data;
        if (data.length >= 2 && _readUint16(data, 0) == queryId) {
          complete(data);
          return;
        }
      }
    },
    onError: (Object error, StackTrace stackTrace) {
      if (!completer.isCompleted) {
        completer.completeError(error, stackTrace);
      }
    },
  );

  timer = Timer(timeout, () => complete(null));
  try {
    socket.send(query, address, port);
    return await completer.future;
  } finally {
    timer.cancel();
    await subscription.cancel();
    socket.close();
  }
}

List<String> _parseTxtResponse(Uint8List response) {
  if (response.length < 12) {
    throw const FormatException('DNS response header is incomplete');
  }

  var offset = 12;
  final questionCount = _readUint16(response, 4);
  final answerCount = _readUint16(response, 6);

  for (var i = 0; i < questionCount; i++) {
    offset = _skipDnsName(response, offset);
    offset = _requireAvailable(response, offset, 4) + 4;
  }

  final txtRecords = <String>[];
  for (var i = 0; i < answerCount; i++) {
    offset = _skipDnsName(response, offset);
    offset = _requireAvailable(response, offset, 10);
    final type = _readUint16(response, offset);
    final recordClass = _readUint16(response, offset + 2);
    final dataLength = _readUint16(response, offset + 8);
    offset += 10;

    final dataStart = _requireAvailable(response, offset, dataLength);
    final dataEnd = dataStart + dataLength;
    if (type == 16 && recordClass == 1) {
      txtRecords.add(_parseTxtData(response, dataStart, dataEnd));
    }
    offset = dataEnd;
  }

  return txtRecords;
}

String _parseTxtData(Uint8List response, int offset, int end) {
  final chunks = <int>[];
  while (offset < end) {
    final length = response[offset];
    offset++;
    offset = _requireAvailable(response, offset, length);
    chunks.addAll(response.sublist(offset, offset + length));
    offset += length;
  }
  return utf8.decode(chunks, allowMalformed: true);
}

int _skipDnsName(Uint8List response, int offset) {
  while (true) {
    offset = _requireAvailable(response, offset, 1);
    final length = response[offset];
    if (length == 0) {
      return offset + 1;
    }
    if ((length & 0xc0) == 0xc0) {
      return _requireAvailable(response, offset, 2) + 2;
    }
    offset = _requireAvailable(response, offset + 1, length) + length;
  }
}

int _requireAvailable(Uint8List response, int offset, int length) {
  if (offset < 0 || offset + length > response.length) {
    throw const FormatException('DNS response is truncated');
  }
  return offset;
}

int _readUint16(Uint8List data, int offset) =>
    (data[offset] << 8) | data[offset + 1];
