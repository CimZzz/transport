import 'dart:convert';
/// Created by CimZzz
/// 回复 Socket
/// 用来与会话 Socket 进行代理匹配

import 'dart:io';

import 'package:stream_data_reader/src/data_reader.dart';
import 'package:transport/src/step.dart';
import 'package:transport/src/transport/new/tunnel.dart';

import '../../proxy_completer.dart';
import 'response_connection.dart';
import 'socket_wrapper.dart';
import 'bridge.dart';

class ReplySocket extends Tunnel {
  ReplySocket({this.ipAddress, this.port, this.clientId, this.matchCode, this.connection});

  /// 桥接服务器 IP 地址
  final String ipAddress;
  /// 桥接服务器端口号
  final int port;

  /// Client Id
  final String clientId;

  /// 匹配码
  final int matchCode;

  /// 对应的响应连接
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

  /// 与 Bridge 握手
  @override
  Future<bool> handShake(SocketWrapper socketWrapper) async {
    final socket = socketWrapper.socket;
    final reader = socketWrapper.reader;

    // 第一步, 发送魔术字
    socket.add([84, 114, 97, 110, 112, 111, 114, 116]);
    await socket.flush();
    // 第二步, 发送 SocketType
    socket.add([kSocketTypeReply]);
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

  /// 处理 Session Request 相关指令
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
