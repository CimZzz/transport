
import 'dart:async';
import 'dart:io';

import 'package:transport/src/async_run.dart';

/// 主函数
void main() async {
  
}

FutureOr<int> a(List<int> params) async {
  var num = 0;
  for(final a in params) {
    num += a;
  }
  throw 123;
}