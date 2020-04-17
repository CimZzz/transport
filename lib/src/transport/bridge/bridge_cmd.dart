
import 'dart:io';

import 'package:transport/src/byte_writer.dart';

import '../../buffer_reader.dart';

class BridgeCommandStream {
	BridgeCommandStream({int mixKey}): _mixKey = mixKey ?? 0;

	int _mixKey;

	Stream<BridgeCommand> wrapperControlSocket(Stream<List<int>> dataStream) async* {
		final reader = BufferReader(rawStream: dataStream);
		while(!reader.isClosed) {
			final cmdCode = await reader.readOneByte();
			final msgType = await reader.readOneByte(timeOut: 2);
			dynamic message;
			switch(msgType) {
			// 00 - Byte
				case 0x00:
					message = (await reader.readOneByte(timeOut: 2)) ^ _mixKey;
					break;
			// 01 - Int(four bytes)
				case 0x01:
					message = await reader.readOneInt(timeOut: 2, mixKey: _mixKey);
					break;
			// 02 - String
				case 0x02:
					// message's length not allow over 255 bytes
					final msgLength = (await reader.readOneByte(timeOut: 2)) ^ _mixKey;
					message = await reader.readString(length: msgLength, timeOut: 5, mixKey: _mixKey);
					break;
				// 0xFF - None
				case 0xFF:
					break;
				default:
					throw Exception('unknow message type');
			}

			// cmd code `0xFF`: change mix key
			if(cmdCode == 0xFF) {
				if(message is! int) {
					throw Exception('invalid mix key');
				}
				_mixKey = message & 0xFF;
			}

			yield BridgeCommand(cmdCode: cmdCode, msgType: msgType, message: message);
		}
	}
}

/// Bridge command
class BridgeCommand {
    BridgeCommand({this.cmdCode, this.msgType, this.message});

    /// About cmd code:
    /// 0xFF - Change mix key
    /// 0x00 - Server Hello
	final int cmdCode;

	/// About message type:
    /// 0xFF - None
    /// 0x00 - Byte
    /// 0x01 - Int(four bytes)
    /// 0x02 - String
	final int msgType;
	final dynamic message;

	void writeCommand({ByteWriter byteWriter, int mixKey}) {
		if(cmdCode != null) {
			byteWriter.writeByte(cmdCode, mixKey: mixKey);
		}
		if(msgType != null) {
			byteWriter.writeByte(msgType, mixKey: mixKey);
		}
		switch(msgType) {
		// 00 - Byte
			case 0x00:
				if(message is int) {
					byteWriter.writeByte(message, mixKey: mixKey);
				}
				break;
		// 01 - Int(four bytes)
			case 0x01:
				if(message is int) {
					byteWriter.writeInt(message, mixKey: mixKey);
				}
				break;
		// 02 - String
			case 0x02:
				if(message is String) {
					byteWriter.writeInt(message.codeUnits.length, mixKey: mixKey);
					byteWriter.writeString(message, mixKey: mixKey);
				}
				break;
		}
	}
}
