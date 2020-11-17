
import 'dart:async';
import 'dart:io';

import 'package:transport/src/async_run.dart';

/// 主函数
void main() async {
  final controller = StreamController<void>();
  controller.stream.listen((event) {
    print('zzzzz');
  }, onError: (e){}, onDone: () {
    print('done');
  });
  controller.add(null);
  controller.close();
}

FutureOr<int> a(List<int> params) async {
  var num = 0;
  for(final a in params) {
    num += a;
  }
  throw 123;
}