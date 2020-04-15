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
  final socket = await Socket.connect('127.0.0.1', 8002);
//  print(await wrapper.readOneByte());
//  final dataList = await wrapper.releaseStream().reduce((previous, element) => previous += element);
  final dataList = await socket.reduce((previous, element) => previous += element);
  print(utf8.decode(dataList));
  socket.destroy();
}