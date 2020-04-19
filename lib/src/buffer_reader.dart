import 'dart:async';

import 'mix_key.dart';

import 'stream_reader.dart';

class BufferReader {
	BufferReader({Stream<List<int>> rawStream}):
			_reader = StreamReader(rawStream);
	
	final StreamReader<List<int>> _reader;

	bool get isClosed => _reader.isEnd;

	List<int> _buffer;
	
	Future<List<int>> _readFromReader([int timeOut]) {
		if(timeOut != null) {
			if(timeOut > 0) {
				return _reader.read().timeout(
					Duration(seconds: timeOut), onTimeout: () {
					throw Exception('time out, over 2 seconds not response');
				});
			}
			else if(timeOut < 0) {
				throw Exception('time out, over 2 seconds not response');
			}
		}
		return _reader.read();
	}
	
	Future<List<int>> readBytes({int length = 1, MixKey mixKey, int timeOut}) async {
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
			if(mixKey != null) {
				mixKey.mixByteList(temp);
			}
			return temp;
		}
		else {
			final returnByteList = _buffer.sublist(0, length);
			_buffer = _buffer.sublist(length);
			if(mixKey != null) {
				mixKey.mixByteList(returnByteList);
			}
			return returnByteList;
		}
	}

	Future<List<int>> readLine({MixKey mixKey, int timeOut}) async {
		var future = Future.sync(() async {
			final terminator = '\n'.codeUnitAt(0);
			if(_buffer == null) {
				_buffer = await _readFromReader();
				if(_buffer == null) {
					// not enough bytes, return
					return null;
				}
			}
			
			var tempBuffer = _buffer;
			var count = tempBuffer.length;
			var j = 0;
			
			while(true) {
				for(var i = 0 ; i < count ; i ++) {
					if(mixKey != null) {
						tempBuffer[i] = mixKey.mixByte(tempBuffer[i], beginKeyIndex: j);
						j ++;
						if(j == 4) {
							j = 0;
						}
					}
					
					if(tempBuffer[i] == terminator) {
						// found
						if(tempBuffer == _buffer) {
							if(i + 1 == count) {
								_buffer = null;
							}
							else {
								_buffer = _buffer.sublist(i + 1);
							}
							return tempBuffer.sublist(0, i);
						}
						else {
							List<int> remainedBytes;
							if(i + 1 == count) {
								remainedBytes = null;
							}
							else {
								remainedBytes = tempBuffer.sublist(i + 1);
							}
							_buffer.addAll(tempBuffer.sublist(0, i));
							tempBuffer = _buffer;
							_buffer = remainedBytes;
							return tempBuffer;
						}
					}
				}
				if(tempBuffer != _buffer) {
					_buffer.addAll(tempBuffer);
				}
				tempBuffer = await _readFromReader();
				if(tempBuffer == null) {
					// not enough bytes, return
					tempBuffer = _buffer;
					_buffer = null;
					return tempBuffer;
				}
				count = tempBuffer.length;
			}
		});
		if(timeOut != null && timeOut > 0) {
			future = future.timeout(Duration(seconds: timeOut), onTimeout: () {
				throw Exception('time out, over 2 seconds not response');
			});
		}
		
		return await future;
	}
	
	Future<int> readOneByte({MixKey mixKey, int timeOut}) async {
		final byteList = await readBytes(mixKey: mixKey, timeOut: timeOut);
		return byteList[0];
	}

	Future<int> readOneInt({bool bigEndian = true, MixKey mixKey, int timeOut}) async {
		final byteList = await readBytes(length: 4, mixKey: mixKey, timeOut: timeOut);
		bigEndian ??= true;
		if(bigEndian) {
			return ((byteList[0] & 0xFF) << 24)
			| ((byteList[1] & 0xFF) << 16)
			| ((byteList[2] & 0xFF) << 8)
			| ((byteList[3] & 0xFF));
		}
		else {
			return ((byteList[3] & 0xFF) << 24)
			| ((byteList[2] & 0xFF) << 16)
			| ((byteList[1] & 0xFF) << 8)
			| ((byteList[0] & 0xFF));
		}
	}
	
	Future<String> readString({int length = 1, MixKey mixKey, int timeOut}) async {
		final byteList = await readBytes(length: length, mixKey: mixKey, timeOut: timeOut);
		return String.fromCharCodes(byteList);
	}

	Future<List<int>> readAnyBytesList({int timeOut}) async {
		if(_buffer != null) {
			return _buffer;
		}
		return await _readFromReader(timeOut);
	}

	Stream<List<int>> releaseStream() async* {
		if(_buffer != null) {
			yield _buffer;
		}
		yield* _reader.releaseStream();
	}
	
	void destroy() {
		_reader.destroy();
	}
}