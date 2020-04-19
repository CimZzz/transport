import 'dart:io';

import '../../stream_transport.dart';
import '../../log_interface.dart';
import '../../server.dart';

class ProxyTransaction extends ServerTransaction {
	ProxyTransaction({LogInterface logInterface, this.remoteAddress, this.remotePort}) :
			super(logInterface: logInterface);
	
	final String remoteAddress;
	final int remotePort;
	
	@override
	Future<void> onAfterServerStarted() {
		if(needLog) {
			logInfo('Proxy server start. Listen on $localPort');
		}
		return super.onAfterServerStarted();
	}
	
	@override
	Future<void> onAfterServerClosed() {
		if(needLog) {
			logInfo('Proxy server closed.');
		}
		return super.onAfterServerClosed();
	}
	
	@override
	void handleSocket(Socket socket) async {
		try {
			if(needLog) {
				logInfo('recv new socket. from ${socket.address.address}');
			}
			// create src transport
			final srcTransport = StreamTransport(
				socket,
				bindData: socket,
				streamDone: (srcTransport, otherTransport) {
					srcTransport.slot.destroy();
					otherTransport?.destroy();
				},
				recvStreamData: (srcTransport, List<int> data) {
					socket.add(data);
					return;
				},
				streamError: (transport, e, [stackTrace]) {
					if(needLog) {
						logWrong('src socket error... $e');
						logError(e, stackTrace);
					}
				}
			);
			// connect remote socket
			final remoteSocket = await Socket.connect(
				remoteAddress, remotePort);
			// create remote transport
			final remoteTransport = StreamTransport(
				remoteSocket,
				bindData: remoteSocket,
				streamDone: (transport, otherTransport) {
					transport.slot.destroy();
					otherTransport?.destroy();
				},
				recvStreamData: (transport, List<int> data) {
					remoteSocket.add(data);
					return;
				},
				streamError: (transport, e, [stackTrace]) {
					if(needLog) {
						logWrong('remote socket error... $e');
						logError(e, stackTrace);
					}
				}
			);
			
			srcTransport.transportToTransport(remoteTransport);
			remoteTransport.transportToTransport(srcTransport);
		} catch(e, stackTrace) {
			if(needLog) {
				logWrong('handle socket error... $e');
				logError(e, stackTrace);
			}
		}
	}
}