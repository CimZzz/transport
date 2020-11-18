import 'dart:async';
import 'dart:io';

import 'package:transport/src/async_run.dart';
import 'package:transport/src/transport/new/bridge.dart';

/// 主函数
void main() {
  TransportBridge.listen(const TransportBridgeOptions(port: 10088));
}

FutureOr<int> a(List<int> params) async {
  var num = 0;
  for (final a in params) {
    num += a;
  }
  throw 123;
}
