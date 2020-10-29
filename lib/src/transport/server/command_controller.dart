import 'dart:async';

import 'package:stream_data_reader/stream_data_reader.dart';

import 'socket_bundle.dart';
import 'normal_step.dart';


/// Command Type - Heartbeat
const Command_Type_Heartbeat = 0x00;

/// Command Type - Reply
const Command_Type_Reply = 0x01;

/// Command Controller
/// Aggregate requests and responses follow in cmdIdx & respIdx, to impl async rpc
abstract class CommandController {
  CommandController(this.socketBundle);

  /// Socket Bundle
  final SocketBundle socketBundle;

  /// Completer Map
  final Map<int, ProxyCompleterStep> completerMap = {};

  /// CommandIndex
  var _index = 0;

  /// Begin command message loop, read from socket and handle by [handleCommand]
  Future<void> beginCommandLoop() {
    final proxyCompleter = Completer();
    transformByteStream(socketBundle.reader.releaseStream(),
        (dataReader) async {
      try {
        final commandType = await dataReader.readOneByte() & 0xFF;
        final idx = await dataReader.readOneByte() & 0xFF;
        final commandResult = await handleCommand(commandType, idx, dataReader);
        if (commandResult == false || commandResult == null) {
          proxyCompleter.completeError('Unsupport command type: $commandType');
        }
      } catch (error) {
        proxyCompleter.completeError(error);
      }
    });
    return proxyCompleter.future;
  }

  /// Get next command idx, range in 1 ~ 255
  int nextCmdIdx() {
    _index ++;
    if(_index > 0xFF) {
      _index = 1;
    }
    return _index;
  }

  /// 建立执行结果回调
  Future<T> waitCommand<T>(int idx) {
    if (completerMap.containsKey(idx)) {
      // 已经存在相同下标的命令，表示错误，返回 null
      return Future<T>.value(null);
    }

    // 10 秒超时
    final step = ProxyCompleterStep<T>(timeout: const Duration(seconds: 10));
    completerMap[idx] = step;
    return step.doAction().whenComplete(() {
      // 执行结束后，强制终止
      completerMap.remove(idx);
    });
  }

  /// 完成指令，配置结果
  void completeCommand(int idx, dynamic result) {
    if (completerMap.containsKey(idx)) {
      completerMap[idx].innerCompleter.complete(result);
      completerMap.remove(idx);
    }
  }

	/// Send command.
	///
	/// All bridge command via this method to send, you can send custom message when
	/// you need by this method
	Future<void> sendCommand(int commandType, {int cmdIdx, List<int> byteBuffer}) async {
		final bytesList = <int>[commandType & 0xFF];

		bytesList.add((cmdIdx ?? 0x00) & 0xFF);
		if(byteBuffer != null) {
			bytesList.addAll(byteBuffer);
		}
		await socketBundle.socket.flush();
	}

  /// Send reply.
  Future<void> sendReply(int srcCommandType, int replyIdx, {List<int> byteBuffer}) async {
		final bytesList = <int>[Command_Type_Reply & 0xFF];

		bytesList.add((replyIdx ?? 0x00) & 0xFF);
		bytesList.add(srcCommandType & 0xFF);
		if(byteBuffer != null) {
			bytesList.addAll(byteBuffer);
		}
		await socketBundle.socket.flush();
  }


	/// Send heartbeat
	///
	///   0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7
	/// + - - - - - - - - - - - - - - - - +
	/// |      type      |    cmdIdx      |
	/// + - - - - - - - - - - - - - - - - +
	///
	/// type: int, 8 bits (1 bytes) , always 0x00
	///
	Future<void> sendHeartbeatTick() async {
		await sendCommand(Command_Type_Heartbeat);
	}

  /// 处理收到的命令
  /// 如果成功处理，那么应返回 true; 如果返回 false, 表示无法识别此命令, 将会立即断开连接
  Future<bool> handleCommand(int commandType, int idx, DataReader reader);
}
