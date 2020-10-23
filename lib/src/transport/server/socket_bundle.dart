
import 'dart:io';

import 'package:stream_data_reader/stream_data_reader.dart';

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
    SocketBundle({this.socket, this.reader, this.encryptFunc, this.decryptFunc, this.encryptParamsFunction, this.analyzeEncryptParamsFunction});

    final Socket socket;
	final ByteBufferReader reader;
	final MessageEncryptFunction encryptFunc;
	final MessageDecryptFunction decryptFunc;
	final MessageEncryptParamsFunction encryptParamsFunction;
	final MessageAnalyzeEncryptParamsFunction analyzeEncryptParamsFunction;

	String clientId;

    Map<String, dynamic> _keyCache;
	Map<String, dynamic> get keyCache => _keyCache ??= {};


	void close() {
		_keyCache?.clear();
		_keyCache = null;
		socket.close().catchError((e) => null);
	}
}