import 'dart:async';
import 'dart:io';

import 'package:transport/src/buffer_reader.dart';
import 'package:transport/src/byte_writer.dart';

typedef CMDWaiter<T> = bool Function(T cmd);

class SocketBundle {
    SocketBundle(Socket socket):
	    socket = socket,
	    address = socket.address.address,
	    port = socket.port,
	    reader =  BufferReader(rawStream: socket),
	    writer = ByteWriter(byteWrite: (List<int> dataList) {
	    	socket?.add(dataList);
	    });
	final Socket socket;
	final String address;
	final int port;
	final ByteWriter writer;
	final BufferReader reader;
	int mixKey = 0;
	void Function(dynamic) cmdWaiter;

	Future<T> wait<T>(CMDWaiter<T> cmdWaiter) {
		final completer = Completer<T>();
		this.cmdWaiter = (cmd) {
			if(cmdWaiter(cmd)) {
				this.cmdWaiter = null;
				completer.complete(cmd);
			}
		};
		return completer.future;
	}

	void destroy() {
		socket?.destroy();
		reader?.destroy();
	}
}