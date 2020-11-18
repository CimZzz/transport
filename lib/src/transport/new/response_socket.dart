import 'dart:convert';

/// Created by CimZzz
/// 响应 Socket
/// 保持与 Bridge Server 的长连接，及时响应代理请求
/// 启动之后支持自动重连桥接服务器，除非手动调用关闭，否则一直处于启动状态

import 'dart:io';

import 'package:stream_data_reader/stream_data_reader.dart';
import 'package:transport/src/framework/general_methods.dart';

import '../../step.dart';
import 'bridge.dart';
import 'command_writer.dart';
import 'connection.dart';
import 'heartbeat_machine.dart';
import 'reply_socket.dart';
import 'socket_wrapper.dart';

/// 响应 Socket 注册配置
/// 一个响应 Socket，可以同时在多个 Bridge Server 上注册，并且支持注册不同的 ClientId
class ResponseRegistrar {
  ResponseRegistrar({this.clientId, this.ipAddress, this.port});

  /// Client Id
  final String clientId;

  /// Bridge Server Ip 地址
  final String ipAddress;

  /// Bridge Server 监听的端口
  final int port;

  @override
  String toString() => '$clientId($ipAddress:$port)';

  @override
  bool operator ==(dynamic other) {
    if (other is ResponseRegistrar) {
      return clientId == other.clientId &&
          ipAddress == other.ipAddress &&
          port == other.port;
    }
    return false;
  }
}

/// 响应 Socket 配置
class ResponseSocketOption {
  ResponseSocketOption({Set<ResponseRegistrar> registrar})
      : assert(registrar != null && registrar.isNotEmpty),
        registrarSet = registrar;

  /// 注册配置集合
  final Set<ResponseRegistrar> registrarSet;
}

/// 响应 Socket
class ResponseSocket {
  ResponseSocket._({this.option});

  /// 绑定桥接服务器
  static ResponseSocket bindBridge({ResponseSocketOption option}) {
    final socket = ResponseSocket._(option: option);
    socket._doBindBridgeServer();
    return socket;
  }

  /// =================================================
  /// 内部成员属性
  /// =================================================

  final ResponseSocketOption option;

  final Set<_ResponseClient> _clientSet = {};

  /// =================================================
  /// 对外暴露方法
  /// =================================================

  /// 关闭 Response Socket
  void close() {
    _clientSet.forEach((client) {
      client.destroy();
    });
    _clientSet.clear();
  }

  /// =================================================
  /// 内部处理方法
  /// =================================================

  /// 执行绑定远程桥接服务器
  void _doBindBridgeServer() {
    option.registrarSet.forEach((registrar) {
      final client = _ResponseClient(registrar);
      _clientSet.add(client);
      client.connect();
    });
  }
}

/// 响应客户端
/// 每个 Bridge Server 对应一个 Client
class _ResponseClient {
  _ResponseClient(this.registrar);

  /// 注册配置
  final ResponseRegistrar registrar;

  /// 当前连接的 Socket
  SocketWrapper socketWrapper;

  /// 判断当前是否被销毁
  var isClosed = false;

  /// Reply Socket 集合
  Set<ReplySocket> replySocketSet;

  /// 心跳机
  HeartbeatMachine heartbeatMachine;

  /// 连接方法
  void connect() {
    Socket.connect(registrar.ipAddress, registrar.port).then((socket) {
      if (isClosed) {
        socket.destroy();
        return;
      }
      socketWrapper = SocketWrapper(socket);
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
    heartbeatMachine?.cancel();
    heartbeatMachine = null;
    replySocketSet?.forEach((replySocket) {
      replySocket.close();
    });
    replySocketSet = null;
    socketWrapper?.close();
    socketWrapper = null;
  }

  /// 销毁 Client 方法
  /// 不再允许该 Client 进行重连
  void destroy() {
    isClosed = true;
    disconnect();
  }

  /// 连接意外断开， 10 秒后执行重连
  void unfortunateError(dynamic reason) {
    if (isClosed) {
      return;
    }
    print('$registrar 连接断开: $reason, 10 秒后尝试重连中...');
    disconnect();
    Future.delayed(const Duration(seconds: 10), () {
      if (isClosed) {
        return;
      }
      print('$registrar 正在尝试重连中...');
      connect();
    });
  }

  /// 处理握手
  Future<bool> _socketHandshake() async {
    final socket = socketWrapper.socket;
    final reader = socketWrapper.reader;

    // 第一步, 发送魔术字
    socket.add([84, 114, 97, 110, 115, 112, 111, 114, 116]);
    await socket.flush();
    // 第二步, 发送 SocketType
    socket.add([kSocketTypeResponse]);
    await socket.flush();
    // 第三步, 发送 ClientId
    final clientIdBytes = utf8.encode(registrar.clientId);
    final length = clientIdBytes.length;
    socket.add([length & 0xFF, (length >> 8) & 0xFF]);
    socket.add(clientIdBytes);
    await socket.flush();
    // 等待 Bridge Server 的响应
    final magicWordBytes = await reader.readBytes(length: 9);
    final magicWord = String.fromCharCodes(magicWordBytes);
    if (magicWord != 'Transport') {
      // 验证失败
      throw Exception('魔术字验证失败');
    }
    return true;
  }

  /// 握手成功回调
  void _handshakeSuccess() async {
    heartbeatMachine = HeartbeatMachine(
      interval: const Duration(seconds: 1),
      remindCount: 6,
      timeoutCount: 10,
    );
    // 启动心跳机
    heartbeatMachine.monitor().listen((_) {
      // 推送心跳报文
      CommandWriter.sendHeartbeat(socketWrapper.socket, isNeedReply: true);
    }, onError: (error) {
      // 心跳超时
      unfortunateError(error);
    });

    try {
      final reader = socketWrapper.reader;
      while (!reader.isEnd) {
        heartbeatMachine?.clearCount();
        final reqType = await reader.readOneByte();
        switch (reqType) {
          case 0x00:
            // 收到心跳报文
            final isNeedReply = await reader.readOneByte() & 0xFF;
            if (isNeedReply == 0x01) {
              await CommandWriter.sendHeartbeat(socketWrapper.socket);
            }
            break;
          case 0x01:
            final matchCode = await reader.readInt(bigEndian: false);
            final replySocket = ReplySocket(
                ipAddress: registrar.ipAddress,
                port: registrar.port,
                clientId: registrar.clientId,
                matchCode: matchCode);
            replySocketSet ??= {};
            replySocketSet.add(replySocket);
            unawait(replySocket.begin().catchError((error) {
              replySocketSet?.remove(replySocket);
            }));
            break;
          default:
            // 收到不支持的指令
            throw Exception('收到其他不支持的指令: $reqType');
            break;
        }
      }
    } catch (error) {
      unfortunateError(error);
    }
  }
}
