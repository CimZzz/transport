import 'dart:convert';

/// Created by CimZzz
/// 回复 Socket
/// 用来与会话 Socket 进行代理匹配

import 'dart:io';

import 'package:stream_data_reader/stream_data_reader.dart';

import '../../proxy_completer.dart';
import 'command_writer.dart';
import 'connection.dart';
import 'heartbeat_machine.dart';
import 'socket_wrapper.dart';
import 'bridge.dart';
import 'tunnel.dart';

class ReplySocket extends Tunnel {
  ReplySocket({this.ipAddress, this.port, this.clientId, this.matchCode});

  /// 桥接服务器 IP 地址
  final String ipAddress;

  /// 桥接服务器端口号
  final int port;

  /// Client Id
  final String clientId;

  /// 匹配码
  final int matchCode;

  /// 对应的响应连接
  Connection connection;

  /// Socket 包装器
  SocketWrapper _wrapper;

  /// 代理连接
  ProxyConnection _proxyConnection;

  /// 心跳机
  HeartbeatMachine _heartbeatMachine;

  /// 握手处理
  Future<void> begin() async {
    final socket = await Socket.connect(ipAddress, port);
    _wrapper = SocketWrapper(socket);
    return await concat(_wrapper);
  }

  /// 关闭流
  void close() {
    connection?.close();
    connection = null;
    _heartbeatMachine?.cancel();
    _heartbeatMachine = null;
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
    socket.add([84, 114, 97, 110, 115, 112, 111, 114, 116]);
    await socket.flush();
    // 第二步, 发送 SocketType
    socket.add([kSocketTypeReply]);
    await socket.flush();
    // 第三步, 发送 ClientId
    final clientIdBytes = utf8.encode(clientId);
    final length = clientIdBytes.length;
    socket.add([length & 0xFF, (length >> 8) & 0xFF]);
    socket.add(clientIdBytes);
    await socket.flush();
    // 第四步, 发送匹配码
    socket.add([
      matchCode & 0xFF,
      (matchCode >> 8) & 0xFF,
      (matchCode >> 16) & 0xFF,
      (matchCode >> 24) & 0xFF
    ]);
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

  /// 处理 Session Request 相关指令
  @override
  Future<void> handleSocketReader(
      DataReader reader, SocketWrapper socket) async {
    _heartbeatMachine?.clearCount();
    final dataType = await reader.readOneByte() & 0xFF;
    switch (dataType) {
      case 0x00:
        // 收到心跳报文
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

        // 检查代理模式
        final proxyMode = await reader.readOneByte() & 0xFF;
        switch (proxyMode) {
          case kProxyMode_Normal:
            // 普通代理模式，需要获取对端的端口
            // 由于对 IPV6 不太熟悉，所以 IP 目前按照字符串格式传输
            final ipLength = await reader.readOneByte() & 0xFF;
            final ipAddress =
                String.fromCharCodes(await reader.readBytes(length: ipLength));
            final port = await reader.readShort(bigEndian: false);
            connection = AddressConnection(ipAddress: ipAddress, port: port);
            break;
          default:
            // 不支持的代理模式，立即中断
            close();
            break;
        }

        // 获取数据分片长度
        final spliceLength = await reader.readShort(bigEndian: false);

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
        connection.doTransport(_proxyConnection).then((_) {
          // 传输完成，一般不会走到这里
        }, onError: (e) {
          // 发生异常, 传输过程中发生失败, 立即结束本次代理
          print('代理连接发生异常: $e');
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
        final bytes = await reader.readBytes(length: length);
        // 写入数据
        _proxyConnection?.addStreamData(bytes);
        return;
    }

    throw Exception('未知指令');
  }
}
