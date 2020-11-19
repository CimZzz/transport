/// Created by CimZzz
/// 命令写入 Writer

import 'dart:io';

import 'package:transport/src/transport/new/socket_wrapper.dart';

class CommandWriter {
  CommandWriter._();

  /// 发送心跳报文
  static void sendHeartbeat(SocketWrapper socket,
      {bool isNeedReply = false}) async {
    socket.add([0x00, isNeedReply ? 0x01 : 0x00]);
    socket.flush();
  }

  /// 发送申请 Reply Socket 指令
  /// 由 Bridge 端发往 Response Socket 端
  static void sendApplyReply(SocketWrapper socket, int matchCode) {
    socket.writeByte(0x01);
    socket.writeInt(matchCode, bigEndian: false);
    socket.flush();
  }
}
