import 'dart:async';
import 'dart:typed_data';

import 'stream_reader.dart';

class BufferReader {
	BufferReader({Stream<List<int>> rawStream, void Function() onDone,}): _reader = StreamReader(rawStream), _onDone = onDone {
		_reader.onDone = () {
			_isClosed = true;
			_onDone?.call();
		};
	}
	final StreamReader<List<int>> _reader;

	var _isClosed = false;
	bool get isClosed => _isClosed;

	void Function() _onDone;
	set onDone (void Function() onDone) {
		_onDone = onDone;
	}

	List<int> _buffer;
	
	Future<List<int>> _readFromReader([int timeOut]) {
		if(timeOut != null && timeOut > 0) {
			return _reader.read().timeout(
				Duration(seconds: timeOut), onTimeout: () {
				throw Exception('time out, over 2 seconds not response');
			});
		}
		return _reader.read();
	}
	
	Future<List<int>> readBytes({int length = 1, int timeOut}) async {
		if(_buffer == null) {
			_buffer = await _readFromReader(timeOut);
			if(_buffer == null) {
				throw Exception('not enough bytes');
			}
		}
		while(_buffer.length < length) {
			final readByteList = await _readFromReader(timeOut);
			if(readByteList == null) {
				throw Exception('not enough bytes');
			}
			_buffer += readByteList;
		}
		if(_buffer.length == length) {
			final temp = _buffer;
			_buffer = null;
			return temp;
		}
		else {
			final returnByteList = _buffer.sublist(0, length);
			_buffer = _buffer.sublist(length);
			return returnByteList;
		}
	}

	Future<int> readOneByte({int timeOut}) async {
		final byteList = await readBytes(timeOut: timeOut);
		return byteList[0];
	}

	Future<int> readOneInt({bool bigEndian = true, int mixKey, int timeOut}) async {
		final byteList = await readBytes(length: 4, timeOut: timeOut);
		bigEndian ??= true;
		if(bigEndian) {
			if(mixKey != null) {
				return (((byteList[0] & 0xFF) ^ mixKey) << 24)
				| (((byteList[1] & 0xFF) ^ mixKey) << 16)
				| (((byteList[2] & 0xFF) ^ mixKey) << 8)
				| (((byteList[3] & 0xFF) ^ mixKey));
			}
			else {
				return ((byteList[0] & 0xFF) << 24)
				| ((byteList[1] & 0xFF) << 16)
				| ((byteList[2] & 0xFF) << 8)
				| ((byteList[3] & 0xFF));
			}
		}
		else {
			if(mixKey != null) {
				return (((byteList[3] & 0xFF) ^ mixKey) << 24)
				| (((byteList[2] & 0xFF) ^ mixKey) << 16)
				| (((byteList[1] & 0xFF) ^ mixKey) << 8)
				| (((byteList[0] & 0xFF) ^ mixKey));
			}
			else {
				return ((byteList[3] & 0xFF) << 24)
				| ((byteList[2] & 0xFF) << 16)
				| ((byteList[1] & 0xFF) << 8)
				| ((byteList[0] & 0xFF));
			}
		}
	}
	
	Future<String> readString({int length = 1, int mixKey, int timeOut}) async {
		final byteList = await readBytes(length: length, timeOut: timeOut);
		return String.fromCharCodes(mixKey != null ? byteList.map((code) => code ^ mixKey) : byteList);
	}

	Future<List<int>> readAnyBytesList({int timeOut}) async {
		if(_buffer != null) {
			return _buffer;
		}
		return await _readFromReader(timeOut);
	}

	Stream<List<int>> releaseStream() async* {
		if(_isClosed) {
			return;
		}
		if(_buffer != null) {
			yield _buffer;
		}
		yield* _reader.releaseStream();
	}

	void destroy() {
		_reader?.destroy();
	}
}