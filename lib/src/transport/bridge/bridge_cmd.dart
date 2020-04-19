import '../../socket_writer.dart';
import '../../mix_key.dart';
import '../../buffer_reader.dart';

/// Bridge server command code
enum BridgeClientCode {
	MixKey,
	RequestSocketReplySuccess,
	RequestSocketReplyFailure,
	ResponseSocketReplySuccess,
	ResponseSocketReplyFailure,
}

/// Bridge client command code
enum BridgeServerCode {
	MixKey,
	ServerHello,
	RequestSocketConfirm,
	RequestUnknownTopic,
	ResponseSocketConfirm,
	NeedResponse,
	TransportRequest,
	TransportResponse
}

/// Bridge message type
enum _BridgeMessageType {
	INT,
	STRING,
	BYTE,
	NONE,
}

/// Determine bridge message type on commandCode
_BridgeMessageType _getMessageType(dynamic commandCode) {
	if (commandCode is BridgeClientCode) {
		switch (commandCode) {
			case BridgeClientCode.MixKey:
				return _BridgeMessageType.INT;
			case BridgeClientCode.RequestSocketReplySuccess:
			case BridgeClientCode.RequestSocketReplyFailure:
			case BridgeClientCode.ResponseSocketReplySuccess:
			case BridgeClientCode.ResponseSocketReplyFailure:
				return _BridgeMessageType.STRING;
		}
	}
	else if (commandCode is BridgeServerCode) {
		switch (commandCode) {
			case BridgeServerCode.MixKey:
				return _BridgeMessageType.INT;
			case BridgeServerCode.ServerHello:
			case BridgeServerCode.NeedResponse:
				return _BridgeMessageType.NONE;
			case BridgeServerCode.RequestSocketConfirm:
			case BridgeServerCode.RequestUnknownTopic:
			case BridgeServerCode.ResponseSocketConfirm:
			case BridgeServerCode.TransportRequest:
			case BridgeServerCode.TransportResponse:
				return _BridgeMessageType.STRING;
		}
	}
	return null;
}


/// Check message is valid
bool _checkMessageValid(_BridgeMessageType type, dynamic msg) {
	switch (type) {
		case _BridgeMessageType.INT:
			return msg is int;
		case _BridgeMessageType.STRING:
			return msg is String;
		case _BridgeMessageType.BYTE:
			return msg is int;
		case _BridgeMessageType.NONE:
			return msg == null;
	}
	return false;
}

/// Bridge command
abstract class BridgeCommand {
	BridgeCommand({this.code, this.message});
	
	/// Command code
	final dynamic code;
	
	/// Command message
	final dynamic message;
	
	/// Write command
	void writeCommand({SocketWriter byteWriter, MixKey mixKey}) {
		final messageType = _getMessageType(code);
		if (messageType == null || !_checkMessageValid(messageType, message)) {
			return;
		}
//		print('send $code');
		byteWriter.writeByte(code.index, mixKey: mixKey);
		byteWriter.writeByte(messageType.index, mixKey: mixKey);
		switch (messageType) {
			case _BridgeMessageType.INT:
				byteWriter.writeInt(message, mixKey: mixKey);
				break;
			case _BridgeMessageType.STRING:
				byteWriter.writeInt(message.codeUnits.length, mixKey: mixKey);
				byteWriter.writeString(message, mixKey: mixKey);
				break;
			case _BridgeMessageType.BYTE:
				byteWriter.writeByte(message, mixKey: mixKey);
				break;
			case _BridgeMessageType.NONE:
				break;
		}
		byteWriter.flush();
	}
}

/// Bridge client command
class BridgeServerCommand extends BridgeCommand {
	BridgeServerCommand({BridgeServerCode code, dynamic message})
		: super(code: code, message: message);
	
	@override
	BridgeServerCode get code => super.code;
}

/// Bridge server command
class BridgeClientCommand extends BridgeCommand {
	BridgeClientCommand({BridgeClientCode code, dynamic message})
		: super(code: code, message: message);
	
	@override
	BridgeClientCode get code => super.code;
}

/// Transform byte stream to bridge command stream
Stream<T> transformBridgeStream<T extends BridgeCommand>({Stream<List<int>> dataStream, MixKey mixKey}) async* {
	if(dataStream == null) {
		return;
	}
	final reader = BufferReader(rawStream: dataStream);
	try {
		while (!reader.isClosed) {
			final cmdCodeByte = await reader.readOneByte(mixKey: mixKey);
			final msgTypeByte = await reader.readOneByte(mixKey: mixKey, timeOut: 2);
			
			dynamic cmdCode;
			dynamic message;
			final msgType = _BridgeMessageType.values[msgTypeByte];
			if(T == BridgeClientCommand) {
				cmdCode = BridgeClientCode.values[cmdCodeByte];
				if(msgType != _getMessageType(cmdCode)) {
					throw Exception('wrong server message type');
				}
			}
			else {
				cmdCode = BridgeServerCode.values[cmdCodeByte];
				if(msgType != _getMessageType(cmdCode)) {
					throw Exception('wrong client message type');
				}
			}
			
			switch(msgType) {
				case _BridgeMessageType.INT:
					message = await reader.readOneInt(mixKey: mixKey, timeOut: 2);
					break;
				case _BridgeMessageType.STRING:
					final msgLength = await reader.readOneInt(
						mixKey: mixKey, timeOut: 2);
					message = await reader.readString(
						length: msgLength, mixKey: mixKey, timeOut: 5);
					break;
				case _BridgeMessageType.BYTE:
					message = await reader.readOneByte(mixKey: mixKey, timeOut: 2);
					break;
				case _BridgeMessageType.NONE:
					message = null;
					break;
			}
			
			// change mix key
			if(cmdCodeByte == 0) {
				mixKey = MixKey(message);
			}
			
//			print('recv $cmdCode');
			if(T == BridgeClientCommand) {
				yield BridgeClientCommand(
					code: cmdCode,
					message: message
				) as T;
			}
			else {
				yield BridgeServerCommand(
					code: cmdCode,
					message: message
				) as T;
			}
		}
	}
	catch (e) {
		if (!reader.isClosed) {
			rethrow;
		}
	}
}
