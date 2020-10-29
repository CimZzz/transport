import 'dart:async';
import 'dart:isolate';

import 'package:transport/src/proxy_completer.dart';

class _MessageContainer<Params, Result> {
  _MessageContainer(this._params, this._receiveSendPort, this._asyncCallback);
  final Params _params;
  final SendPort _receiveSendPort;
  final FutureOr<Result> Function(Params params) _asyncCallback;

  FutureOr<Result> apply() async {
    return await _asyncCallback(_params);
  }
}

Future<Result> asyncRun<Params, Result>(
  Params params,
  FutureOr<Result> Function(Params params) asyncCallback,
) async {
  final receivePort = ReceivePort();
  final exitPort = ReceivePort();
  final errorPort = ReceivePort();
  final completer = ProxyCompleter<Result>();
  final isolate = await Isolate.spawn(
      _asyncRun,
      _MessageContainer<Params, Result>(
          params, receivePort.sendPort, asyncCallback),
      errorsAreFatal: true,
      onError: errorPort.sendPort,
      onExit: exitPort.sendPort);

  receivePort.listen((message) {
    completer.complete(message);
  });

  errorPort.listen((dynamic errorData) {
    final exception = Exception(errorData[0]);
    final stack = StackTrace.fromString(errorData[1] as String);
    completer.completeError(exception, stack);
  });

  exitPort.listen((dynamic exitData) {
    completer.completeError(Exception('unknown isolate exit'));
  });

  try {
    return await completer.future;
  } catch (error) {
    rethrow;
  } finally {
    receivePort.close();
    exitPort.close();
    errorPort.close();
    isolate.kill();
  }
}

void _asyncRun<Params, Result> (
    _MessageContainer<Params, Result> container) async {
  container._receiveSendPort.send(await container.apply());
}
