import 'dart:convert';
import 'dart:io';

import 'package:transport/transport.dart';

import '../../stream_transport.dart';
import '../../log_interface.dart';
import '../../server.dart';
import '../../socket_bundle.dart';

class HttpProxyTransaction extends ServerTransaction {
	HttpProxyTransaction({
		LogInterface logInterface,
		String bridgeClientAddress,
		int bridgeClientPort
	}) : clientAddress = bridgeClientAddress ?? (bridgeClientPort != null ? '127.0.0.1' : null),
			clientPort = bridgeClientPort ?? (bridgeClientAddress != null ? 80 : null),
			super(logInterface: logInterface);

	final String clientAddress;
	final int clientPort;

	@override
	Future<void> onAfterServerStarted() {
		if(needLog) {
			logInfo('Http Proxy server start. Listen on $localPort');
		}
		return super.onAfterServerStarted();
	}
	
	@override
	Future<void> onAfterServerClosed() {
		if(needLog) {
			logInfo('Http Proxy server closed.');
		}
		return super.onAfterServerClosed();
	}
	
	@override
	void handleSocket(Socket socket) async {
		final socketBundle = SocketBundle(socket);
		try {
			if(needLog) {
				logInfo('recv new socket. from ${socket.address.address}');
			}
			
			String firstLine;
			String host;
			int port;
			SocketBundle remoteSocketBundle;
			
			var byteList = await socketBundle.reader.readLine(timeOut: 5);
			firstLine = utf8.decode(byteList);
			
			final firstLineSplit = firstLine.split(' ');
			if(firstLineSplit.length != 3) {
				// first line format error
				throw Exception('unknow http status line');
			}
			
			if(firstLineSplit[0].toUpperCase() == 'CONNECT') {
				// Connect method
				// create TCP Tunnel
				final hostPortStr = firstLineSplit[1].split(':');
				if(hostPortStr.length != 1 && hostPortStr.length != 2) {
					throw Exception('unknow host ${firstLineSplit[1]}');
				}
				host = hostPortStr[0];
				port = hostPortStr.length == 2 ? int.tryParse(hostPortStr[1]) : 80;
				if(port == null) {
					throw Exception('unknow port ${hostPortStr[1]}');
				}
				
				// read remained connect header
				while(true) {
					// current do not handle remained header
					byteList = await socketBundle.reader.readLine(timeOut: 5);
					if(byteList.length == 1 && byteList[0] == 13) {
						break;
					}
				}

				if(clientAddress != null && clientPort != null) {
					remoteSocketBundle = SocketBundle(await Socket.connect(clientAddress, clientPort));
					socketBundle.addChild(remoteSocketBundle);
					remoteSocketBundle.writer.writeByte(host.codeUnits.length);
					remoteSocketBundle.writer.writeString(host);
					remoteSocketBundle.writer.writeInt(port);
				}
				else {
					remoteSocketBundle = SocketBundle(await Socket.connect(host, port));
					socketBundle.addChild(remoteSocketBundle);
				}

				socketBundle.writer.writeString('HTTP/1.1 200 Connection Established\r\n\r\n');
				socketBundle.writer.flush();
			}
			else {
				final url = firstLineSplit[1];
				var beginIdx = url.indexOf('://');
				if(beginIdx == -1) {
					throw Exception('unknow host ${firstLineSplit[1]}');
				}
				beginIdx += 3;
				var endIdx = url.indexOf('/', beginIdx);
				if(endIdx == -1) {
					endIdx = url.length;
				}
				
				final hostPortStr = firstLineSplit[1].substring(beginIdx, endIdx).split(':');
				if(hostPortStr.length != 1 && hostPortStr.length != 2) {
					throw Exception('unknow host ${firstLineSplit[1]}');
				}
				host = hostPortStr[0];
				port = hostPortStr.length == 2 ? int.tryParse(hostPortStr[1]) : 80;
				if(port == null) {
					throw Exception('unknow port ${hostPortStr[1]}');
				}

				if(clientAddress != null && clientPort != null) {
					remoteSocketBundle = SocketBundle(await Socket.connect(clientAddress, clientPort));
					socketBundle.addChild(remoteSocketBundle);
					remoteSocketBundle.writer.writeByte(host.codeUnits.length);
					remoteSocketBundle.writer.writeString(host);
					remoteSocketBundle.writer.writeInt(port);
				}
				else {
					remoteSocketBundle = SocketBundle(await Socket.connect(host, port));
					socketBundle.addChild(remoteSocketBundle);
				}

				remoteSocketBundle.writer.writeByteList(byteList);
				remoteSocketBundle.writer.writeByte('\n'.codeUnitAt(0));
				// read remained header, and post to remote socket
				remoteSocketBundle.writer.flush();
			}
			
			if(needLog) {
				logInfo('proxy ${firstLineSplit[0].toUpperCase()} to $host:$port');
			}
			// create src transport
			final srcTransport = StreamTransport(
				socketBundle.reader.releaseStream(),
				bindData: socketBundle,
				streamDone: (srcTransport, otherTransport) {
					if(needLog) {
						logInfo('proxy completed...');
					}
					srcTransport.slot.destroy();
					otherTransport?.destroy();
				},
				recvStreamData: (srcTransport, List<int> data) {
					srcTransport.slot.socket.add(data);
					return;
				},
				streamError: (transport, e, [stackTrace]) {
					if(needLog) {
						logWrong('src socket error... $e');
						logError(e, stackTrace);
					}
				}
			);
			// create remote transport
			final remoteTransport = StreamTransport(
				remoteSocketBundle.reader.releaseStream(),
				bindData: remoteSocketBundle,
				streamDone: (transport, otherTransport) {
					transport.slot.destroy();
					otherTransport?.destroy();
				},
				recvStreamData: (transport, List<int> data) {
					remoteSocketBundle.socket.add(data);
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
			socketBundle.destroy();
			if(needLog) {
				logWrong('handle socket error... $e');
				logError(e, stackTrace);
			}
		}
	}
}