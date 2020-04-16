import 'dart:async';
import 'dart:io';

import '../server_base.dart';

class TransportProxyServer extends BaseServer {

	TransportProxyServer({int localPort, bool allowCache, this.remoteAddress, this.remotePort}) :
			allowCache = allowCache ?? true,
			super(localPort: localPort);

	final bool allowCache;
	final String remoteAddress;
	final int remotePort;

	@override
	Future<void> startServer() {
		return super.startServer()
			..then((value) {logInfo('Transport Proxy listen on $localPort...');});
	}

	@override
	void acceptSocket(Socket socket) {
		logInfo('proxy new socket. from: ${socket.address.address}');
		_transportSocket(socket, () async {
			return Socket.connect(remoteAddress ?? '127.0.0.1', remotePort);
		}, onError: (e, [stackTrace]) {
			logWrong(e);
		}, allowCache: allowCache);
	}
}

/// Transport socket data
void _transportSocket(Socket srcSocket, Future<Socket> Function() remoteSocketCreator, {
	bool allowCache,
	void Function(dynamic error, [StackTrace stackTrace]) onError,
	Future<List<int>> Function(List<int>) encodeCallback,
	Future<List<int>> Function(List<int>) decodeCallback,
}) {

	Socket remoteSocket;
	StreamSubscription remoteSubscription;
	srcSocket.listen((List<int> event) async {
		try {
			if (remoteSocket == null) {
				remoteSocket = await remoteSocketCreator();
				remoteSubscription = remoteSocket.listen((event) async {
					try {
						if (decodeCallback != null) {
							srcSocket.add(await decodeCallback(event));
						}
						else {
							srcSocket.add(event);
						}
					}
					catch (e, stackTrace) {
						// transfer data occur error
						onError?.call(e, stackTrace);
					}
				}, onError: onError ?? (e, stackTrace) {
					// occur error
				}, onDone: () {
					remoteSubscription?.cancel();
					remoteSubscription = null;
					remoteSocket = null;
					if(!allowCache) {
						srcSocket.destroy();
					}
				}, cancelOnError: true);
			}
			if (encodeCallback != null) {
				remoteSocket.add(await encodeCallback(event));
			}
			else {
				remoteSocket.add(event);
			}
		}
		catch (e, stackTrace) {
			// transfer data occur error
			onError?.call(e, stackTrace);
			srcSocket.destroy();
			remoteSocket?.destroy();
		}
	}, onError: onError ?? (e, stackTrace) {
		// occur error
		srcSocket.destroy();
		remoteSocket?.destroy();
	}, onDone: () {
		// completed
		remoteSubscription?.cancel();
		remoteSocket?.destroy();
		remoteSubscription = null;
		remoteSocket = null;
		srcSocket.destroy();
	}, cancelOnError: true);
}