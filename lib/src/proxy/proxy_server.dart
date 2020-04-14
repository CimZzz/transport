import 'dart:async';
import 'dart:io';
import '../server_base.dart';

class TransportProxyServer extends BaseServer {

	TransportProxyServer({int localPort, this.remoteAddress, this.remotePort}): super(localPort: localPort);

	final String remoteAddress;
	final int remotePort;
	
	@override
	void acceptSocket(Socket socket) {
		_transportSocket(socket, () async {
			return Socket.connect(remoteAddress, remotePort);
		}, onError: (e, [stackTrace]) {
			logError(e, stackTrace);
		});
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
				}, cancelOnError: true);
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
	}, cancelOnError: true);
}