import 'dart:io';

import 'transport_server.dart';

class TransportSrcServer extends TransportServer {

	TransportSrcServer({this.localPort, this.remoteSinkAddress, this.remoteSinkPort});

	final int localPort;
	final String remoteSinkAddress;
	final int remoteSinkPort;

	ServerSocket _serverSocket;
	bool _isRunning = false;

	@override
	bool get isRunning => _isRunning;

	@override
	Future<void> startServer() async {
		if (isRunning) {
			return;
		}
		_isRunning = true;
		_serverSocket = await ServerSocket.bind('127.0.0.1', localPort);
		_serverSocket.listen((socket) async {
			transportSocket(socket, () async {
				return Socket.connect(remoteSinkAddress, remoteSinkPort);
			}, onError: (e, [stackTrace]) {
				logError(e, stackTrace);
			});
		}, onError: (e, stackTrace) {
			logError(e, stackTrace);
			closeServer();
		});
		return;
	}

	@override
	Future<void> closeServer() async {
		if (isRunning) {
			_isRunning = false;
			try {
				await _serverSocket.close();
			}
			catch (e, stackTrace) {
				logError(e, stackTrace);
			}
			return;
		}
		return;
	}
}