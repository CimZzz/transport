import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';


import '../lib/src/bridge/transport_server.dart';
import '../lib/src/bridge/transport_bridge.dart';
import '../lib/src/console_log_interface.dart';
import '../lib/src/proxy/proxy_server.dart';
import '../lib/src/stream_reader.dart';


void main() async {
  final server = await ServerSocket.bind('127.0.0.1', 8002);
  await for (var socket in server) {
    print('recv remote socket');
    socket.add(utf8.encode('hello transport'));
    socket.destroy();
  }
}