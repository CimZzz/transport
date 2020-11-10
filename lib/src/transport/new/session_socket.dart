/// Created by CimZzz
/// 会话 Socket 类型
/// 由请求端 Socket 发出建立会话，期望响应 Socket 回复该会话从而建立一个
/// 完整的代理会话连接
/// 
/// 请求 Reply Socket 流程:
/// 
/// Request Socket ------> Bridge ------> Response Socket 
///                                               |
///                                               |
///                                               |
/// Request Socket <------ Bridge <------ Reply Socket
/// 
/// 在这之后 Request Socket 会发送一个 Session Socket, 来和 Reply Socket 建立完整的代理连接

import 'dart:io';

import 'package:stream_data_reader/stream_data_reader.dart';

import '../../proxy_completer.dart';
import 'socket_wrapper.dart';
import 'tunnel.dart';
import 'bridge.dart';
import 'response_connection.dart';


class SessionSocket extends Tunnel {
  SessionSocket(this.ipAddress, this.port, this.clientId, this.matchCode);

  /// 桥接服务器 IP 地址
  final String ipAddress;
  /// 桥接服务器端口号
  final int port;
  /// Client Id
  final String clientId;
  /// 匹配码
  final int matchCode;
  /// 对应的传输连接
  TransportConnection connection;
  /// Socket 包装器
  SocketWrapper _wrapper;
  /// 代理连接
  ProxyConnection _proxyConnection;

  /// 握手处理
  Future<void> begin() async {
    final socket = await Socket.connect(ipAddress, port);
    _wrapper =  SocketWrapper(socket);
    return await concat(_wrapper);
  }

  /// 关闭流
  void close() {
    connection?.close();
    connection = null;
    _proxyConnection?.close();
    _proxyConnection = null;
    _wrapper?.close();
    _wrapper = null;
  }

  @override
  Future<bool> handShake(SocketWrapper socketWrapper) async {
    final socket = socketWrapper.socket;
    final reader = socketWrapper.reader;

    // 第一步, 发送魔术字
    socket.add([84, 114, 97, 110, 112, 111, 114, 116]);
    await socket.flush();
    // 第二步, 发送 SocketType
    socket.add([kSocketTypeSession]);
    await socket.flush();
    // 第三步, 发送匹配码
    socket.add([matchCode & 0xFF, (matchCode >> 8) & 0xFF]);
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

  /// 握手成功后，启动心跳计时器，并且发送 0x01 指令开始进行代理
  @override
  Future<void> handShakeSuccess(ProxyCompleter completer, SocketWrapper socketWrapper) async {
    socketWrapper.socket.add([0x01]);
    await socketWrapper.socket.flush();
    return await super.handShakeSuccess(completer, socketWrapper);
  }

  /// 处理 Reply Socket 相关指令
  @override
  Future<void> handleSocketReader(DataReader reader, Socket socket) async {
    final dataType = await reader.readOneByte() & 0xFF;
    switch(dataType) {
      case 0x00:
      // 心跳数据，忽略
      return;
      case 0x01:
      // 一切准备就绪，开始进行数据传递，这时需要建立连接
      if(_proxyConnection != null) {
        // 重复建立连接，处理异常
        close();
        return;
      }
      _proxyConnection = ProxyConnection((data) {
        final length = data.length;
        socket.add([0x02, length & 0xFF, (length >> 8) & 0xFF]);
        socket.add(data);
        return socket.flush();
      });
      // ignore: unawaited_futures
      connection.doTransport(_proxyConnection).then((_) {
        // 传输完成，一般不会走到这里
      }, onError: (e) {
        // 发生异常, 传输过程中发生失败, 立即结束本次代理
        close();
      });
      return;

      case 0x02:
      // 未加密数据，直接用来做传输
      if(_proxyConnection == null) {
        // 未建立连接就开始传递数据, 立即结束本次代理
        close();
        return;
      }

      // 读取数据长度
      final length = await reader.readShort(bigEndian: false);
      // 写入数据
      _proxyConnection?.addStreamData(await reader.readBytes(length: length));
      return;
    }

    throw Exception('未知指令');
  }
}