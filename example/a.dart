
import 'dart:async';

import 'package:transport/src/async_run.dart';

/// 主函数
void main() async {
  final list = [1, 2, 3, 4];
  try {
    final result = await asyncRun(list, a);
  print('num: $result');
  }
  catch(e) {
    print('aaaax: $e');
  }
  

}

FutureOr<int> a(List<int> params) async {
  var num = 0;
  for(final a in params) {
    num += a;
  }
  throw 123;
  return num;
}