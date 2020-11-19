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
import 'dart:convert';

import 'package:stream_data_reader/stream_data_reader.dart';

import '../../proxy_completer.dart';
import 'command_writer.dart';
import 'heartbeat_machine.dart';
import 'socket_wrapper.dart';
import 'tunnel.dart';
import 'bridge.dart';
import 'connection.dart';

class SessionSocketOption {
  SessionSocketOption(
      {this.clientId,
      this.ipAddress,
      this.port,
      this.proxyIpAddress,
      this.proxyPort});

  /// 想要请求的响应端 ClientId
  final String clientId;

  /// Bridge Server Ip 地址
  final String ipAddress;

  /// Bridge Server 监听的端口
  final int port;

  /// 代理端访问 Ip 地址
  final String proxyIpAddress;

  /// 代理端访问端口
  final int proxyPort;
}

class SessionSocket extends Tunnel {
  SessionSocket({this.option, Connection connection})
      : _connection = connection;

  final SessionSocketOption option;

  /// 对应的传输连接
  Connection _connection;

  /// Socket 包装器
  SocketWrapper _wrapper;

  /// 代理连接
  ProxyConnection _proxyConnection;

  /// 心跳机
  HeartbeatMachine _heartbeatMachine;

  /// 握手处理
  Future<void> begin() async {
    final socket = await Socket.connect(option.ipAddress, option.port);
    _wrapper = SocketWrapper(socket);
    return await concat(_wrapper);
  }

  /// 关闭流
  void close() {
    _connection?.close();
    _connection = null;
    _heartbeatMachine?.cancel();
    _heartbeatMachine = null;
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
    socket.add([84, 114, 97, 110, 115, 112, 111, 114, 116]);
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
    if (magicWord != 'Transport') {
      // 验证失败
      throw Exception('魔术字验证失败');
    }
    return true;
  }

  /// 握手成功后，启动心跳计时器，并且发送 0x01 指令开始进行代理
  @override
  Future<void> handShakeSuccess(
      ProxyCompleter completer, SocketWrapper socketWrapper) async {
    // 开启心跳机
    _heartbeatMachine ??= HeartbeatMachine(
        interval: const Duration(seconds: 1), remindCount: 6, timeoutCount: 10);
    _heartbeatMachine.monitor().listen((_) {
      // 发送提醒心跳
      CommandWriter.sendHeartbeat(socketWrapper, isNeedReply: true);
    }, onError: (error) {
      // 心跳超时
      close();
    });
    socketWrapper.socket.add([0x01]);
    await socketWrapper.socket.flush();
    return await super.handShakeSuccess(completer, socketWrapper);
  }

  /// 处理 Reply Socket 相关指令
  @override
  Future<void> handleSocketReader(
      DataReader reader, SocketWrapper socket) async {
    _heartbeatMachine?.clearCount();
    final dataType = await reader.readOneByte() & 0xFF;
    switch (dataType) {
      case 0x00:
        // 心跳数据
        final isNeedReply = await reader.readOneByte() & 0xFF;
        if (isNeedReply == 0x01) {
          await CommandWriter.sendHeartbeat(socket);
        }
        return;
      case 0x01:
        // 一切准备就绪，开始进行数据传递，这时需要建立连接
        if (_proxyConnection != null) {
          // 重复建立连接，处理异常
          close();
          return;
        }

        // 目前默认都是普通代理模式
        // 发送 Ip 字节长度, Ip 字节数组, 端口号, 分片长度(目前默认 1024)
        final ipAddress = utf8.encode(option.proxyIpAddress);
        final ipLength = ipAddress.length;
        socket.add([kProxyMode_Normal, ipLength & 0xFF]);
        socket.add(ipAddress);
        socket.add([option.proxyPort & 0xFF, (option.proxyPort >> 8) & 0xFF]);
        final spliceLength = 1024;
        socket.add([spliceLength & 0xFF, (spliceLength >> 8) & 0xFF]);
        await socket.flush();

        _proxyConnection = ProxyConnection((data) {
          var length = data.length;
          var beginIdx = 0;
          while (length > 0) {
            var nextDataLength = spliceLength;
            if (length < spliceLength) {
              nextDataLength = length;
            }

            socket.writeByte(0x02);
            socket.writeShort(nextDataLength, bigEndian: false);
            socket.add(data.sublist(beginIdx, beginIdx + nextDataLength));
            socket.flush();
            length -= nextDataLength;
            beginIdx += nextDataLength;
          }
        });

        // ignore: unawaited_futures
        _connection.doTransport(_proxyConnection).then((_) {
          // 传输完成，一般不会走到这里
        }, onError: (e) {
          // 发生异常, 传输过程中发生失败, 立即结束本次代理
          close();
        });
        return;

      case 0x02:
        // 未加密数据，直接用来做传输
        if (_proxyConnection == null) {
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
