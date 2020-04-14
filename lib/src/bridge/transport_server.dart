import 'dart:async';
import 'dart:io';
import 'package:transport/src/bridge/socket_wrapper.dart';

import '../server_base.dart';

class TransportServer extends BaseServer {
	
	TransportServer({
		int localPort,
		this.topic,
		this.remoteTopic,
		this.transportPort,
		this.bridgeAddress,
		this.bridgePort
	}): super(localPort: localPort);
	
	final String topic;
	final String remoteTopic;
	final int transportPort;
	final String bridgeAddress;
	final int bridgePort;
	
	SocketWrapper _controlSocket;
	
	@override
	Future<void> startServer() async {
		await super.startServer();
		await _connectControlSocket();
		if(isRunning) {
			logInfo('Transport server listen on $localPort...');
		}
	}
	
	@override
	void acceptSocket(Socket socket) async {
	
	}
	
	void _connectControlSocket() async {
		try {
			if(!isRunning) {
				destroyServer();
				return;
			}
			final socket = await Socket.connect(bridgeAddress, bridgePort);
			_controlSocket = SocketWrapper(socket);
			final dataList = [0xFF];
			final topicList = topic.runes.toList();
			dataList.add(topicList.length);
			dataList.addAll(topicList);
			socket.add(dataList);
			final res = await _controlSocket.readOneByte();
			switch(res) {
				case 0xFE:
					// control socket success
					_controlSocket.onDone = () {
						// remote server down, retry to connect it
						_connectControlSocket();
					};
					_controlSocket.releaseStream().listen((event) {
						// send request socket to remote server
					});
					break;
				case 0xFD:
					// control socket repeat, stop
					destroyServer();
					break;
				default:
					// unsupported repeat, stop
					destroyServer();
					break;
			}
		}
		catch(e) {
		
		}
	}
}