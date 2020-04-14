import 'dart:async';
import 'dart:io';
import '../server_base.dart';
import 'socket_wrapper.dart';

class TransportBridge extends BaseServer{
	TransportBridge({int localPort}): super(localPort: localPort);
	
	final _controlSocketMap = <String, SocketWrapper>{};
	final _pendingSocketMap = <String, List<SocketWrapper>>{};
	
	@override
	Future<void> startServer() {
		return super.startServer()
		..then((value) {logInfo('Transport bridge listen on $localPort...');});
	}
	
	@override
	void acceptSocket(Socket socket) async {
		final socketWrapper = SocketWrapper(socket);
		final address = socketWrapper.socket.address.address;
		try {
			// receiver src socket
			// authorization socket type
			final firstByte = await socketWrapper.readOneByte();
			final topicLength = await socketWrapper.readOneByte();
			final topic = await socketWrapper.readString(length: topicLength);
			switch(firstByte) {
				case 0xFF:
					// receive new control socket
					if(_controlSocketMap.containsKey(topic)) {
						// repeat control socket
						socket.add([0xFD]);
						socket.destroy();
						logWarn('reapeat control socket. topic: $topic, from $address');
					}
					else {
						_controlSocketMap[address] = socketWrapper;
						socketWrapper.streamReader.releaseReadStream();
						socketWrapper.onDone = () {
							logInfo('remove control socket. topic: $topic, from $address');
						};
						logInfo('add control socket. topic: $topic, from $address');
						socket.add([0xFE]);
						// check pending socket map
						final pendingList = _pendingSocketMap[address];
						if(pendingList != null) {
							// call socket wrapper for new socket
							socketWrapper.socket.add(List.filled(pendingList.length, 0xFF));
						}
					}
					break;
				case 0xFE:
					// receive new response socket
					// check pending socket map
					final firstSocket = _removePendingSocket(topic, index: 0);
					if(firstSocket != null) {
						firstSocket.activate();
						_transportSocket(firstSocket, socketWrapper);
					}
					else {
						// unused response socket, closed...
						socket.destroy();
					}
					break;
				case 0xFD:
					// receive new request socket
					// notify control socket need provide new response socket
					
					final pendingList = _pendingSocketMap.putIfAbsent(topic, () => []);
					pendingList.add(socketWrapper);
					socketWrapper.wait(10, onTimeOut: (socketWrapper) {
						_removePendingSocket(topic, socketWrapper: socketWrapper);
						logWarn('request socket wait time out. topic: $topic, from $address');
					});
					logInfo('add request socket. topic: $topic, from $address');
					break;
			}
		}
		catch(error) {
			logWrong('handle socket error. from $address, $error');
		}
	}
	
	SocketWrapper _removePendingSocket(String topic, {int index, SocketWrapper socketWrapper}) {
		final pendingList = _pendingSocketMap[topic];
		if(pendingList != null) {
			
			final firstSocket = index != null ? pendingList.removeAt(index) : null;
			if(socketWrapper != null) {
				pendingList.remove(socketWrapper);
			}
			if(pendingList.isEmpty) {
				_pendingSocketMap.remove(topic);
			}
			return firstSocket;
		}
		return null;
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