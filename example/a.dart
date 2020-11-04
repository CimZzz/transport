
import 'dart:async';
import 'dart:io';

import 'package:transport/src/async_run.dart';

/// 主函数
void main() async {
  Socket.connect('xinfayun.com.cn', 1883).then((value) {
    print('connect success');
  }, onError: (e) {
    print('$e');
  });

  await Future.delayed(Duration(seconds: 60));
}

FutureOr<int> a(List<int> params) async {
  var num = 0;
  for(final a in params) {
    num += a;
  }
  throw 123;
}