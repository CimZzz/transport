/// Created by CimZzz
/// 序列化类，用来异步序列化对象，减少主 Isolate 的延迟

import 'dart:async';
import 'dart:convert';

import '../../async_run.dart';

///
/// Transport Client Options
///
class TransportClientInfo {
  TransportClientInfo({this.clientId});
  final String clientId;
}

///
/// Serialize Transport Client
///

Future<List<int>> serializeTransportClient(Iterable<TransportClientInfo> clients) async {
  if(clients.isEmpty) {
    return [];
  }

  final buffer = await asyncRun(
    clients,
    _serializeTransportClient
  );

  return buffer;
}

FutureOr<List<int>> _serializeTransportClient(Iterable<TransportClientInfo> clients) async {
  final buffer = <int>[];
  clients.forEach((client) {
    final clientId = client.clientId;
    final clientIdBytes = utf8.encode(clientId);
    buffer.add(clientIdBytes.length & 0xFF);
    buffer.addAll(clientIdBytes);
  });
  return buffer;
}