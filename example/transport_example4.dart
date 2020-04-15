import 'dart:async';
import 'dart:io';
import 'dart:math';


import '../lib/src/bridge/transport_server.dart';
import '../lib/src/bridge/transport_bridge.dart';
import '../lib/src/console_log_interface.dart';
import '../lib/src/proxy/proxy_server.dart';
import '../lib/src/stream_reader.dart';


void main() async {
  final server = TransportServer(
      localPort: 8001,
      topic: 'CimZzz',
      remoteTopic: 'TiwZzz',
      transportPort: 9001,
      bridgeAddress: '127.0.0.1',
      bridgePort: 8000
  );
  server.logInterface = ConsoleLogInterface();
  await server.startServer();
}