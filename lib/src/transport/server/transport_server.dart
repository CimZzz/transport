
import 'dart:io';

import 'package:stream_data_reader/stream_data_reader.dart';
import 'package:transport/src/transport/server/socket_bundle.dart';

/// When server close, call this callback.
/// * Only call it at first time.
///
/// If closed reason is error, call it with error information
typedef ServerCloseCallback = void Function(dynamic error, [StackTrace stackTrace]);


/// Transport Client
class TransportClient {
    TransportClient(this.clientId, this.socketBundle);

	final String clientId;
	final SocketBundle socketBundle;
}

/// Transport server
/// listen port and process transport connection
/// need specify server ip and port
class TransportServer {
    TransportServer(this.ip, this.port, {ServerCloseCallback serverCloseCallback}):
		    assert(ip != null),
		    assert(port != null),
		    _serverCloseCallback = serverCloseCallback;

    /// Server ip address
	final String ip;

	/// Server port
	final int port;

	/// Server close
	final ServerCloseCallback _serverCloseCallback;

	/// Whether server is closed
	var _isClosed = false;

	/// Server socket
	ServerSocket _serverSocket;

	/// Do listen.
    /// When listen success, return true, either return false or throw exception
	Future<bool> listen() async {
		final socket = await ServerSocket.bind(ip, port);
		if(_isClosed) {
			await socket.close();
		}
		socket.listen((socket) {
			_processSocketAccept(socket);
		}, onError: (error, [stackTrace]) {
			/// todo 处理错误异常回调
		});
		return true;
	}

	/// Close transport server
	void close(dynamic error, [stackTrace]) {
		if(!_isClosed) {
			_isClosed = true;
			/// todo 关闭逻辑
			/// 1. 关闭 Server Socket
			/// 2. 触发回调
		}
	}

	/// Process incoming socket.
    /// Socket has 3 type:
    ///
    /// Type One:
    ///
    /// Control Socket, which communicate with transport server reality, send
    /// some control command to implement transaction.
    ///
    /// Type Two:
    ///
    /// Request Socket, request peer socket. When server receive it, will call peer control socket to construct specify connection
    /// to response to request socket
    ///
    /// Type Three:
    ///
    /// Response Socket
    ///
	void _processSocketAccept(Socket socket) {
		final socketBundle = SocketBundle (
			socket: socket,
			reader: ByteBufferReader(StreamReader(socket)),
			// todo 加密方法
			encryptFunc: null,
			// todo 解密方法
			decryptFunc: null,
			// 加密参数方法（Server 端用不到）
			encryptParamsFunction: null,
			// todo 解析加密参数方法
			analyzeEncryptParamsFunction: null,
		);
	}
}