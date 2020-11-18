/// Created by CimZzz
/// 数据交互通道
/// 用于两个 Socket 之间的数据交互与拦截

import 'dart:io';

import 'package:stream_data_reader/stream_data_reader.dart';
import 'package:transport/src/step.dart';
import 'package:transport/src/transport/new/socket_wrapper.dart';

import '../../proxy_completer.dart';

/// 数据交互通道基类
abstract class Tunnel {
  final ProxyCompleter _completer = ProxyCompleter();

  Future<void> concat(SocketWrapper socketWrapper) {
    final timeoutStep = TimeoutStep(timeout: const Duration(seconds: 10));
    timeoutStep.doAction().then((_) {
      return handShakeSuccess(_completer, socketWrapper);
    }, onError: (e, stackTrace) {
      _completer.completeError(e, stackTrace);
    }).catchError((e, stackTrace) {
      _completer.completeError(e, stackTrace);
    });
    handShake(socketWrapper).then((value) {
      timeoutStep.innerCompleter.complete();
    }, onError: (error, stackTrace) {
      timeoutStep.innerCompleter.completeError(error, stackTrace);
    });

    return _completer.future;
  }

  Future<void> handShakeSuccess(
      ProxyCompleter completer, SocketWrapper socketWrapper) async {
    try {
      final reader = socketWrapper.reader;
      while (!reader.isEnd) {
        await handleSocketReader(reader, socketWrapper.socket);
      }
    } catch (e, stackTrace) {
      completer.completeError(e, stackTrace);
    }
    return null;
  }

  Future<bool> handShake(SocketWrapper socketWrapper);
  Future<void> handleSocketReader(DataReader reader, Socket socket) => null;
}
