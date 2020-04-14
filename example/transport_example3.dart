import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../lib/src/bridge/transport_bridge.dart';
import '../lib/src/console_log_interface.dart';
import '../lib/src/proxy/proxy_server.dart';
import '../lib/src/stream_reader.dart';

Stream stream() async* {
  for(var i in [1, 2, 3, 4]) {
    yield i;
  };
}

void main() async {
  Stream<int> stream;
  await for (var i in stream) {
    print(i);
  }
}