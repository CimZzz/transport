import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'stream_reader.dart';

class SocketWrapper {
	SocketWrapper(Socket socket, {void Function() onDone}):
			socket = socket,
			streamReader = StreamReader(socket, onDone: onDone);
	final Socket socket;
	final StreamReader<Uint8List> streamReader;
	
	Uint8List buffer;
	
	set onDone (void Function() onDone) {
		streamReader.onDone = onDone;
	}
	
	Future<Uint8List> readFromReader(int timeOut) {
		return streamReader.read().timeout(Duration(seconds: timeOut ?? 2), onTimeout: () {
			throw Exception('time out, over 2 seconds not response');
		});
	}
	
	Future<Uint8List> readBytes({int length = 1, int timeOut}) async {
		if(buffer == null) {
			buffer = await readFromReader(timeOut);
			if(buffer == null) {
				throw Exception('not enough bytes');
			}
		}
		while(buffer.length < length) {
			final readByteList = await readFromReader(timeOut);
			if(readByteList == null) {
				throw Exception('not enough bytes');
			}
			buffer += readByteList;
		}
		if(buffer.length == length) {
			final temp = buffer;
			buffer = null;
			return temp;
		}
		else {
			final returnByteList = buffer.sublist(0, length);
			buffer = buffer.sublist(length);
			return returnByteList;
		}
	}
	
	Future<int> readOneByte({int timeOut}) async {
		final byteList = await readBytes(timeOut: timeOut);
		return byteList[0];
	}
	
	Future<String> readString({int length = 1, int timeOut}) async {
		final byteList = await readBytes(length: length, timeOut: timeOut);
		return String.fromCharCodes(byteList);
	}

	Stream<Uint8List> releaseStream() async* {
		if(buffer != null) {
			yield buffer;
		}
		yield* streamReader.releaseStream();
	}

	StreamSubscription _waitSubscription;
	
	/// Wait some second, if not activate in future, destroy it.
	void wait(int second, {void Function(SocketWrapper) onTimeOut}) {
		if(_waitSubscription != null) {
			_waitSubscription.cancel();
		}
		
		_waitSubscription = Future.delayed(Duration(seconds: second)).asStream().listen((event) {
			onTimeOut(this);
		});
	}
	
	/// Activate the socket, stop waiting...
	void activate() {
		_waitSubscription?.cancel();
		_waitSubscription = null;
	}

	/// destroy
	void destroy() {
		socket.destroy();
		streamReader.destroy();
	}
}