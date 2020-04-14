import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../lib/src/bridge/transport_bridge.dart';
import '../lib/src/console_log_interface.dart';
import '../lib/src/proxy/proxy_server.dart';

void main() async {
  final bridge = TransportBridge(localPort: 10086);
  bridge.logInterface = ConsoleLogInterface();
  await bridge.startServer();
  var _ = Socket.connect('127.0.0.1', 10086).then((socket) {
    final list = <int>[];
    final name = 'abc'.runes.toList();
    list.add(0xFF);
    list.add(name.length);
    list.addAll(name);
    socket.add(list);
    print('sended');
    Future.delayed(const Duration(seconds: 20), () {
      socket.destroy();
    });
  });
  _ = Socket.connect('127.0.0.1', 10086).then((socket) {
    final list = <int>[];
    final name = 'abc'.runes.toList();
    list.add(0xFD);
    list.add(name.length);
    list.addAll(name);
    socket.add(list);
  });
}