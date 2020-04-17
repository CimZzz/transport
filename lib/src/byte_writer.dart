
/// Write byte callback
typedef onByteWrite = void Function(List<int> bytes);

/// Handle any-format byte output
class ByteWriter {
	ByteWriter({this.byteWrite});

	/// Write byte callback
	final onByteWrite byteWrite;

	/// Call `onByteWrite` callback for writing byte list
	void _writeByteList(List<int> byteList) {
		byteWrite?.call(byteList);
	}

	/// Write one byte
	void writeByte(int byte, {int mixKey}) {
		_writeByteList([mixKey != null ? byte & mixKey : byte]);
	}

	/// Transform string to byte list
	void writeString(String str, {int mixKey}) {
		final byteList = str.codeUnits;
		_writeByteList(mixKey != null ? byteList.map((e) => e ^ mixKey) : byteList);
	}

	/// Transform int to four-byte list
	void writeInt(int number, {bool bigEndian = true, int mixKey}) {
		final byteList = List<int>(4);
		if(bigEndian ?? true) {
			if(mixKey != null) {
				byteList[3] = (number & 0xFF) ^ mixKey;
				number >>= 8;
				byteList[2] = (number & 0xFF) ^ mixKey;
				number >>= 8;
				byteList[1] = (number & 0xFF) ^ mixKey;
				number >>= 8;
				byteList[0] = (number & 0xFF) ^ mixKey;
			}
			else {
				byteList[3] = number & 0xFF;
				number >>= 8;
				byteList[2] = number & 0xFF;
				number >>= 8;
				byteList[1] = number & 0xFF;
				number >>= 8;
				byteList[0] = number & 0xFF;
			}
		}
		else {
			if(mixKey != null) {
				byteList[0] = (number & 0xFF) ^ mixKey;
				number >>= 8;
				byteList[1] = (number & 0xFF) ^ mixKey;
				number >>= 8;
				byteList[2] = (number & 0xFF) ^ mixKey;
				number >>= 8;
				byteList[3] = (number & 0xFF) ^ mixKey;
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
		}

		_writeByteList(byteList);
	}
}