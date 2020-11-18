/// Created by CimZzz
/// 请求 Socket
/// 用来连接 Bridge 服务器，作为代理的 Src 端

import 'dart:io';

import 'package:transport/src/transport/new/connection.dart';
import 'package:transport/src/transport/new/session_socket.dart';

import 'socket_wrapper.dart';

/// 请求 Socket 配置
class RequestServerOption {
  const RequestServerOption({
    this.clientId,
    this.ipAddress,
    this.port,
    this.localIpAddress = '0.0.0.0',
    this.localPort,
    this.proxyIpAddress = '0.0.0.0',
    this.proxyPort,
  });

  /// 想要请求的响应端 ClientId
  final String clientId;

  /// Bridge Server Ip 地址
  final String ipAddress;

  /// Bridge Server 监听的端口
  final int port;

  /// 本地监听 Ip 地址
  final String localIpAddress;

  /// 本地监听端口
  final int localPort;

  /// 代理端访问 Ip 地址
  final String proxyIpAddress;

  /// 代理端访问端口
  final int proxyPort;
}

/// 请求 Socket
class RequestServer {
  RequestServer._({this.option});

  static Future<RequestServer> listen({RequestServerOption option}) async {
    final bridge = RequestServer._(option: option);
    final socket =
        await ServerSocket.bind(option.localIpAddress, option.localPort);
    bridge._serverSocket = socket;
    socket.listen(bridge._processSocketAccept, onError: (error, [stackTrace]) {
      bridge.close();
    });
    print(
        'RequestServer is listening on ${option.localIpAddress}:${option.localPort}');
    return bridge;
  }

  /// =================================================
  /// 对外暴露方法
  /// =================================================

  void close() {
    if (!_isClosed) {
      _isClosed = true;
      final tempSet = _sessionSet;
      _sessionSet = null;
      tempSet.forEach((session) {
        session.close();
      });
      _serverSocket?.close();
      _serverSocket = null;
    }
  }

  /// =================================================
  /// 内部成员属性
  /// =================================================

  /// 请求 Socket 配置
  RequestServerOption option;

  /// 判断是否关闭
  var _isClosed = false;

  /// Server Socket 对象
  ServerSocket _serverSocket;

  /// Session Socket 集合
  Set<SessionSocket> _sessionSet;

  /// =================================================
  /// 内部处理方法
  /// =================================================

  /// 处理接收到的 Socket
  void _processSocketAccept(Socket socket) {
    print('收到新的连接');
    // 每个收到的 Socket，都会重新创建一个 SessionSocket 连接 Bridge Server，尝试请求代理
    final sessionSocket = SessionSocket(
        option: SessionSocketOption(
            clientId: option.clientId,
            ipAddress: option.ipAddress,
            port: option.port,
            proxyIpAddress: option.proxyIpAddress,
            proxyPort: option.proxyPort),
        connection: SocketConnection(SocketWrapper(socket)));

    _sessionSet ??= {};
    _sessionSet.add(sessionSocket);

    // 关闭回调
    sessionSocket.begin().catchError((error) {
      _sessionSet?.remove(sessionSocket);
    });
  }
}
