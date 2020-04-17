import 'dart:async';
import 'dart:typed_data';

import 'stream_reader.dart';

class BufferReader {
	BufferReader({Stream<List<int>> rawStream}): _reader = StreamReader(rawStream);
	final StreamReader<List<int>> _reader;
	
	Uint8List buffer;
	
	Future<Uint8List> _readFromReader([int timeOut]) {
		if(timeOut != null && timeOut > 0) {
			return _reader.read().timeout(
				Duration(seconds: timeOut), onTimeout: () {
				throw Exception('time out, over 2 seconds not response');
			});
		}
		return _reader.read();
	}
	
	Future<Uint8List> readBytes({int length = 1, int timeOut}) async {
		if(buffer == null) {
			buffer = await _readFromReader(timeOut);
			if(buffer == null) {
				throw Exception('not enough bytes');
			}
		}
		while(buffer.length < length) {
			final readByteList = await _readFromReader(timeOut);
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
		yield* _reader.releaseReadStream();
	}
}