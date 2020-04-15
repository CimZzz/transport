import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';


import 'package:transport/src/bridge/socket_wrapper.dart';

import '../lib/src/bridge/transport_server.dart';
import '../lib/src/bridge/transport_bridge.dart';
import '../lib/src/console_log_interface.dart';
import '../lib/src/proxy/proxy_server.dart';
import '../lib/src/stream_reader.dart';


void main() async {
  final localSocket = await Socket.connect('127.0.0.1', 9001);
  final localSocketWrapper = SocketWrapper(localSocket);

  localSocketWrapper.releaseStream().listen((event) {
    print('second event: $event');
  }, onError: (error, stackTrace) {
//    onError?.call(error, stackTrace);
  }, onDone: () {
    print('second done');
//    firstSocket.destroy();
    localSocketWrapper.destroy();
  }, cancelOnError: true);
}