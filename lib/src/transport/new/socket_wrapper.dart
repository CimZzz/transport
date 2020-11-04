/// Created by CimZzz
/// Socket 包装器
/// 包含多种 Socket 信息，方便快速查询使用

import 'dart:io';

import 'package:stream_data_reader/stream_data_reader.dart';

class SocketWrapper {
  SocketWrapper(this.socket): 
    address = socket.address.address,
    port = socket.port,
    reader = ByteBufferReader(StreamReader(socket));
  
  /// Socket 对象
  final Socket socket;

  /// Socket 地址
  final String address;

  /// Socket 端口
  final int port;

  /// Socket Reader
	ByteBufferReader reader;

	/// 关闭当前连接
	void close() {
		socket.close().catchError((e) => null);
    socket.destroy();
	}
}