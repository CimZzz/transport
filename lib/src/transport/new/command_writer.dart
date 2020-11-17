/// Created by CimZzz
/// 命令写入 Writer

import 'dart:io';

class CommandWriter {
  CommandWriter._();

  /// 发送心跳报文
  static Future<void> sendHeartbeat(Socket socket, {bool isNeedReply = false}) {
    socket.add([0x00, isNeedReply ? 0x01 : 0x00]);
    return socket.flush();
  }

  /// 发送申请 Reply Socket 指令
  /// 由 Bridge 端发往 Response Socket 端
  static Future<void> sendApplyReply(Socket socket, int matchCode) {
    socket.add([
      0x01,
      matchCode & 0xFF,
      (matchCode >> 8) & 0xFF,
      (matchCode >> 16) & 0xFF,
      (matchCode >> 24) & 0xFF,
     ]);
     return socket.flush();
  }
}