import 'dart:async';
import 'dart:convert';

import 'package:transport/src/async_run.dart';

///
/// Transport Client Options
///
class TransportClientOptions {
  TransportClientOptions({this.clientId});
  final String clientId;
}

///
/// Serialize Transport Client
///

Future<List<int>> serializeTransportClient(Iterable<TransportClientOptions> clients) async {
  if(clients.isEmpty) {
    return [];
  }

  final buffer = await asyncRun(
    clients,
    _serializeTransportClient
  );

  return buffer;
}

FutureOr<List<int>> _serializeTransportClient(Iterable<TransportClientOptions> clients) async {
  final buffer = <int>[];
  clients.forEach((client) {
    final clientId = client.clientId;
    final clientIdBytes = utf8.encode(clientId);
    buffer.add(clientIdBytes.length & 0xFF);
    buffer.addAll(clientIdBytes);
  });
  return buffer;
}