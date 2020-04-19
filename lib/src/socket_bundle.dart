import 'dart:io';
import 'node_chain.dart';
import 'buffer_reader.dart';
import 'socket_writer.dart';

/// Socket bundle
class SocketBundle<T> {
	SocketBundle(Socket socket):
			socket = socket,
			address = socket.address.address,
			port = socket.port,
			remotePort = socket.remotePort,
			reader =  BufferReader(rawStream: socket),
			writer = SocketWriter(socket:  socket);
	final Socket socket;
	final String address;
	final int port;
	final int remotePort;
	T slot;
	final SocketWriter writer;
	final BufferReader reader;
	NodeChain _socketChain;
	var _isDestroy = false;
	bool get isDestroy => _isDestroy;
	
	void addChild(SocketBundle socketBundle) {
		_socketChain ??= NodeChain(this, onDrop: (chain) => chain.nodeData.destroy());
		socketBundle._socketChain ??= NodeChain(socketBundle, onDrop: (chain) => chain.nodeData.destroy());
		_socketChain.addChild(socketBundle._socketChain);
	}
	
	void destroy() {
		if(!isDestroy) {
			_isDestroy = true;
			_socketChain?.dropSelf();
			reader.destroy();
			socket?.destroy();
		}
	}
}