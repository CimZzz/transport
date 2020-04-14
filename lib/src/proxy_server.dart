import 'dart:async';
import 'dart:io';
import 'server_base.dart';

class TransportProxyServer extends BaseServer {

	TransportProxyServer({this.localPort, this.remoteAddress, this.remotePort});

	final int localPort;
	final String remoteAddress;
	final int remotePort;

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
			_transportSocket(socket, () async {
				return Socket.connect(remoteAddress, remotePort);
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

/// Transport socket data
void _transportSocket(Socket srcSocket, Future<Socket> Function() remoteSocketCreator, {
	void Function(dynamic error, [StackTrace stackTrace]) onError,
	Future<List<int>> Function(List<int>) encodeCallback,
	Future<List<int>> Function(List<int>) decodeCallback,
}) {
	Socket remoteSocket;
	StreamSubscription remoteSubscription;
	srcSocket.listen((List<int> event) async {
		try {
			if(remoteSocket == null) {
				remoteSocket = await remoteSocketCreator();
				remoteSubscription = remoteSocket.listen((event) async {
					try {
						if(decodeCallback != null) {
							srcSocket.add(await decodeCallback(event));
						}
						else {
							srcSocket.add(event);
						}
					}
					catch(e, stackTrace) {
						// transfer data occur error
						onError?.call(e, stackTrace);
					}
				}, onError: onError ?? (e, stackTrace) {
					// occur error
				}, onDone: () {
					remoteSubscription?.cancel();
					remoteSubscription = null;
					remoteSocket = null;
				});
			}
			if(encodeCallback != null) {
				remoteSocket.add(await encodeCallback(event));
			}
			else {
				remoteSocket.add(event);
			}
		}
		catch(e, stackTrace) {
			// transfer data occur error
			onError?.call(e, stackTrace);
		}
	}, onError: onError ?? (e, stackTrace) {
		// occur error
	}, onDone: () {
		// completed
		remoteSubscription?.cancel();
		remoteSocket?.destroy();
		remoteSubscription = null;
		remoteSocket = null;
	});
}