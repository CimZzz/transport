
import 'dart:io';

import 'package:stream_data_reader/stream_data_reader.dart';
import 'package:transport/src/string_utils.dart';

/// 控制 Socket 类型
const kSocketTypeControl = 0;

/// 请求 Socket 类型
const kSocketTypeRequest = 1;

/// 响应 Socket 类型
const kSocketTypeResponse = 2;

/// Message Encrypt Function
typedef MessageEncryptFunction = List<int> Function(SocketBundle, List<int>);

/// Message Decrypt Function
typedef MessageDecryptFunction = List<int> Function(SocketBundle, List<int>);

/// Message Encrypt Params Getter Function
typedef MessageEncryptParamsFunction = Future<List<int>> Function();

/// Message Analyze Encrypt Params Function
typedef MessageAnalyzeEncryptParamsFunction = void Function(SocketBundle, List<int>);

/// Socket bundle
class SocketBundle {
    SocketBundle({this.socket, this.reader, this.encryptFunc, this.decryptFunc, this.encryptParamsFunction, this.analyzeEncryptParamsFunction}):
		    ipAddress = socket.address.address;

    final Socket socket;
    final String ipAddress;
	final ByteBufferReader reader;
	final MessageEncryptFunction encryptFunc;
	final MessageDecryptFunction decryptFunc;
	final MessageEncryptParamsFunction encryptParamsFunction;
	final MessageAnalyzeEncryptParamsFunction analyzeEncryptParamsFunction;

	String clientId;
	int socketType;

    Map<String, dynamic> _keyCache;
	Map<String, dynamic> get keyCache => _keyCache ??= {};

	/// Close current connection
	void close() {
		_keyCache?.clear();
		_keyCache = null;
		socket.close().catchError((e) => null);
	}

	@override
	String toString() {
		return 'SocketBundle(ClientId: \'$clientId\', socketType: ${StringUtils.getSocketTypeStr(socketType)})';
	}
}