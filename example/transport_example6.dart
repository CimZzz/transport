import 'dart:io';
import 'package:transport/transport.dart';

void main() async {
  final file = File('/Users/wangyanxiong/Downloads/proxy.pac');
  final bytes = await file.readAsBytes();
  final server = await ServerSocket.bind('127.0.0.1', 80);
  await for (var socket in server) {
    socket.add(bytes);
    socket.destroy();
  }
}