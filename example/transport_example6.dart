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
  final file = File('/Users/wangyanxiong/Downloads/proxy.pac');
  final bytes = await file.readAsBytes();
  final server = await ServerSocket.bind('127.0.0.1', 80);
  await for (var socket in server) {
    socket.add(bytes);
    socket.close();
  }
}