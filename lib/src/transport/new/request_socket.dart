/// Created by CimZzz
/// 请求 Socket
/// 用来连接 Bridge 服务器，作为代理的 Src 端

import 'dart:io';
import 'dart:convert';

import 'package:stream_data_reader/stream_data_reader.dart';

import '../../step.dart';
import 'socket_wrapper.dart';
import 'bridge.dart';

/// 请求 Socket 配置
class RequestSocketOption {
  RequestSocketOption({this.clientId, this.ipAddress, this.port});

  /// 想要请求的响应端 ClientId
  final String clientId;

  /// Bridge Server Ip 地址
  final String ipAddress;

  /// Bridge Server 监听的端口
  final int port;
}

/// 请求 Socket
class RequestSocket {
  RequestSocket._({this.option});

  static RequestSocket bindBridge(RequestSocketOption option) {
    final socket = RequestSocket._(option: option);
    return socket;
  }

  /// =================================================
  /// 内部成员属性
  /// =================================================
  
  /// 请求 Socket 配置
  RequestSocketOption option;

  /// 判断是否关闭
  var _isClosed = false;

  /// 连接 Socket
  SocketWrapper _socketWrapper;

  /// =================================================
  /// 对外暴露方法
  /// =================================================
  
  
  /// 执行绑定远程桥接服务器
  void connect() {
    Socket.connect(option.ipAddress, option.port).then((socket) {
      if(_isClosed) {
        socket.destroy();
        return;
      }
      _socketWrapper = SocketWrapper(socket);
      final timeoutStep = TimeoutStep(timeout: Duration(seconds: 10));
      timeoutStep.doAction().then((result) {
        /// 握手成功
        _handshakeSuccess();
      }, onError: (e, [stackTrace]) {
        /// 握手失败
        unfortunateError(e);
      });
      timeoutStep.innerCompleter.complete(_socketHandshake());
    }, onError: (e, [stackTrace]) {
      unfortunateError(e);
    });
  }

  /// 断开连接方法
  void disconnect() {
    _socketWrapper?.close();
    _socketWrapper = null;
  }

  /// 销毁 Request Socket
  void destroy() {
    if(!_isClosed) {
      _isClosed = true;
      disconnect();
    }
  }
  
  /// =================================================
  /// 内部处理方法
  /// =================================================
  

  /// 连接意外断开， 10 秒后执行重连
  void unfortunateError(dynamic reason) {
    if(_isClosed) {
      return;
    }
    print('连接断开: $reason, 10 秒后尝试重连中...');
    disconnect();
    Future.delayed(const Duration(seconds: 10), () {
      if(_isClosed) {
        return;
      }
      print('正在尝试重连中...');
      connect();
    });
  }

  /// 处理握手
  Future<bool> _socketHandshake() async {
    final socket = _socketWrapper.socket;
    final reader = _socketWrapper.reader;

    // 第一步, 发送魔术字
		socket.add([84, 114, 97, 110, 112, 111, 114, 116]);
		await socket.flush();
    // 第二步, 发送 SocketType
    socket.add([kSocketTypeRequest]);
    await socket.flush();
    // 第三步, 发送 ClientId
    final clientIdBytes = utf8.encode(option.clientId);
    final length = clientIdBytes.length;
    socket.add([length & 0xFF, (length >> 8) & 0xFF]);
    socket.add(clientIdBytes);
    await socket.flush();
    // 等待 Bridge Server 的响应
		final magicWordBytes = await reader.readBytes(length: 9);
		final magicWord = String.fromCharCodes(magicWordBytes);
		if(magicWord != 'Transport') {
			// 验证失败
      throw Exception('魔术字验证失败');
		}
    return true;
  }

  /// 握手成功回调
  void _handshakeSuccess() async {
    transformByteStream(_socketWrapper.reader.releaseStream(), (reader) async {
      try {
        final reqType = await reader.readOneByte();
        switch(reqType) {
          case 0x00:
          // 收到心跳报文
            break;
          default:
          // 收到不支持的指令
            throw Exception('收到其他不支持的指令: $reqType');
            break;
        }
      }
      catch(e) {
        unfortunateError(e);
      }
    });
  }
}