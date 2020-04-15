import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../lib/src/bridge/transport_bridge.dart';
import '../lib/src/console_log_interface.dart';
import '../lib/src/proxy/proxy_server.dart';
import '../lib/src/stream_reader.dart';


void main() async {
  final bridge = TransportBridge(localPort: 8000);
  bridge.logInterface = ConsoleLogInterface();
  await bridge.startServer();
}