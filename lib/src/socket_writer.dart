
import 'dart:async';
import 'dart:io';

import 'mix_key.dart';

/// Write byte callback
typedef onByteWrite = void Function(List<int> bytes);

/// Handle any-format byte output
class SocketWriter {
	SocketWriter({Socket socket}): socket = socket;

	List<int> _buffer;
	
	/// Write byte callback
	final Socket socket;
	
	/// Flush byte data completer
	/// Prevent sending multi data cause an exception
	Completer _flushCompleter;
	
	var _isFlushError = false;
	

	/// Call `onByteWrite` callback for writing byte list
	void _writeByteList(List<int> byteList) {
		_buffer ??= [];
		_buffer.addAll(byteList);
	}
	
	void flush() async {
		if(_flushCompleter != null) {
			await _flushCompleter.future;
		}
		if(_isFlushError) {
			return;
		}
		_flushCompleter = Completer();
		socket.add(_buffer);
		_buffer = null;
		try {
			await socket.flush();
		}
		catch(e) {
			// do noting
			_isFlushError = true;
		}
		_flushCompleter.complete();
		_flushCompleter = null;
		
	}
	
	/// Write one byte
	void writeByte(int byte, {MixKey mixKey}) {
		final byteList = [byte];
		if(mixKey != null) {
			mixKey.mixByteList(byteList);
		}
		_writeByteList(byteList);
	}
	
	/// Write one byte
	void writeByteList(List<int> byteList, {MixKey mixKey}) {
		if(mixKey != null) {
			mixKey.mixByteList(byteList);
		}
		_writeByteList(byteList);
	}

	/// Transform string to byte list
	void writeString(String str, {MixKey mixKey}) {
		var byteList = str.codeUnits;
		if(mixKey != null) {
			byteList = mixKey.mixByteList(byteList, modifyOriginList: false);
		}
		_writeByteList(byteList);
	}

	/// Transform int to four-byte list
	void writeInt(int number, {bool bigEndian = true, MixKey mixKey}) {
		final byteList = List<int>(4);
		if(bigEndian ?? true) {
			byteList[3] = number & 0xFF;
			number >>= 8;
			byteList[2] = number & 0xFF;
			number >>= 8;
			byteList[1] = number & 0xFF;
			number >>= 8;
			byteList[0] = number & 0xFF;
		}
		else {
			byteList[0] = number & 0xFF;
			number >>= 8;
			byteList[1] = number & 0xFF;
			number >>= 8;
			byteList[2] = number & 0xFF;
			number >>= 8;
			byteList[3] = number & 0xFF;
		}

		if(mixKey != null) {
			mixKey.mixByteList(byteList);
		}
		
		_writeByteList(byteList);
	}
}