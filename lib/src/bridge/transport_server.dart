import 'dart:async';
import 'dart:io';
import 'package:transport/src/bridge/socket_wrapper.dart';

import '../server_base.dart';

class TransportServer extends BaseServer {
	
	TransportServer({
		int localPort,
		this.topic,
		this.remoteTopic,
		this.transportAddress,
		this.transportPort,
		this.bridgeAddress,
		this.bridgePort
	}): super(localPort: localPort);
	
	final String topic;
	final String remoteTopic;
	final String transportAddress;
	final int transportPort;
	final String bridgeAddress;
	final int bridgePort;
	
	SocketWrapper _controlSocket;
	var isRemoteConnected = false;
	final pendingSocketList = <SocketWrapper>[];
	
	@override
	Future<void> startServer() async {
		await super.startServer();
		await _connectControlSocket();
		if(isRunning) {
			logInfo('Transport server listen on $localPort...');
		}
	}
	
	@override
	void acceptSocket(Socket socket) {
		final socketWrapper = SocketWrapper(socket);
		if(isRemoteConnected) {
			_handleLocalSocket(socketWrapper);
		}
		else {
			pendingSocketList.add(socketWrapper);
			socketWrapper.wait(60, onTimeOut: (wrapper) {
				pendingSocketList.remove(wrapper);
				wrapper.destroy();
				logWarn('raw socket wait time out');
			});
		}
	}
	
	Future<void> _connectControlSocket() async {
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
						logWarn('cannot connect remote server, will retry after 10 second...');
						isRemoteConnected = false;
						Future.delayed(const Duration(seconds: 10), () {
							_connectControlSocket();
						});
					};
					_controlSocket.releaseStream().listen((event) {
						// send request socket to remote server
						event.forEach((element) {
							switch(element) {
								case 0xFF:
									_handleRemoteSocket();
									break;
								default:
									logWarn('recv unknown control code: $element');
									break;
							}
						});
					});
					isRemoteConnected = true;
					logInfo('control socket connected... address: $bridgeAddress, port: $bridgePort');
					// handle pending socket
					while(pendingSocketList.isNotEmpty) {
						_handleLocalSocket(pendingSocketList.removeAt(0));
					}
					break;
				case 0xFD:
					// control socket repeat, stop
					logWrong('control socket repeat on topic: $topic, stop');
					destroyServer();
					break;
				default:
					// unsupported reply, stop
					logWrong('unsupported reply $res, stop');
					destroyServer();
					break;
			}
		}
		catch(e) {
			logWrong('occur error $e, will retry after 10 second...');
			await Future.delayed(const Duration(seconds: 10));
			return await _connectControlSocket();
		}
	}

	/// Recv local socket, and request remote server to transport it
	void _handleLocalSocket(SocketWrapper socketWrapper) async {
		SocketWrapper requestSocketWrapper;
		try {
			logInfo('handle local socket...');
			socketWrapper.activate();
			// send request socket;
			final requestSocket = await Socket.connect(bridgeAddress, bridgePort);
			requestSocketWrapper = SocketWrapper(requestSocket);
			final dataList = [0xFD];
			final topicList = remoteTopic.runes.toList();
			dataList.add(topicList.length);
			dataList.addAll(topicList);
			requestSocket.add(dataList);
			final response = await requestSocketWrapper.readOneByte(timeOut: 60);
			if(response == 0xFF) {
				// success, do transport
				_transportSocket(socketWrapper, requestSocketWrapper);
				return;
			}
			else {
				// Unknown request reply
				logWrong('Unknown request reply: $response, stop...');
			}
		}
		catch(e) {
			logWrong('request error: $e, stop...');
		}
		requestSocketWrapper?.destroy();
		socketWrapper.destroy();
	}
	
	void _handleRemoteSocket() async {
		SocketWrapper remoteResponseSocketWrapper;
		SocketWrapper localSocketWrapper;
		try {
			logInfo('handle remote socket...');
			final remoteSocket = await Socket.connect(bridgeAddress, bridgePort);
			remoteResponseSocketWrapper = SocketWrapper(remoteSocket);
			final dataList = [0xFE];
			final topicList = topic.runes.toList();
			dataList.add(topicList.length);
			dataList.addAll(topicList);
			remoteSocket.add(dataList);

			final localSocket = await Socket.connect(transportAddress ?? '127.0.0.1', transportPort);
			localSocketWrapper = SocketWrapper(localSocket);

			_transportSocket(remoteResponseSocketWrapper, localSocketWrapper);
			return;
		}
		catch(e) {
			logWrong('response error: $e, stop...');
		}
		remoteResponseSocketWrapper?.destroy();
		localSocketWrapper?.destroy();
	}
}


/// Transport socket data
void _transportSocket(SocketWrapper firstSocketWrapper, SocketWrapper secondSocketWrapper, {
	void Function(dynamic error, [StackTrace stackTrace]) onError,
	Future<List<int>> Function(List<int>) encodeCallback,
	Future<List<int>> Function(List<int>) decodeCallback,
}) {
	final firstSocket = firstSocketWrapper.socket;
	final secondSocket = secondSocketWrapper.socket;

	firstSocketWrapper.releaseStream().listen((event) {
		secondSocket.add(event);
	}, onError: (error, stackTrace) {
		onError?.call(error, stackTrace);
	}, onDone: () {
		firstSocket.destroy();
		secondSocket.destroy();
	}, cancelOnError: true);

	secondSocketWrapper.releaseStream().listen((event) {
		firstSocket.add(event);
	}, onError: (error, stackTrace) {
		onError?.call(error, stackTrace);
	}, onDone: () {
		firstSocket.destroy();
		secondSocket.destroy();
	}, cancelOnError: true);
}