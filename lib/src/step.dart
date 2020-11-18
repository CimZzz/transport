import 'dart:async';

import 'package:transport/src/proxy_completer.dart';
import 'package:transport/src/transport/server/socket_bundle.dart';

/// Base Step
abstract class BaseStep<T> {
  BaseStep(this.timeout);

  /// Step time out
  final Duration timeout;

  /// Completer
  final ProxyCompleter<T> _completer = ProxyCompleter();

  /// Step Function
  Future<T> doAction() {
    if (!_completer.isCompleted) {
      onStepAction().timeout(timeout).then((value) {
        _completer.complete(value);
      }, onError: (error, [stackTrace]) {
        print(error);
        _completer.completeError(onStepError(error) ?? error);
      });
    }
    return _completer.future;
  }

  Future<T> onStepAction();

  dynamic onStepError(dynamic e) {
    return e;
  }
}

/// 超时处理步骤
class TimeoutStep<T> extends BaseStep<T> {
  TimeoutStep({Duration timeout}) : super(timeout);

  final ProxyCompleter<T> innerCompleter = ProxyCompleter();

  @override
  Future<T> onStepAction() async {
    return await innerCompleter.future;
  }
}
