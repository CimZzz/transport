import 'dart:convert';

import '../../step.dart';
import 'socket_bundle.dart';

/// Server 2 Client, hand shake resp
class HandShakeRespStep extends BaseSocketBundleStep<bool> {
	HandShakeRespStep(SocketBundle socketBundle, {this.registerClientCallback}) : super(socketBundle, Duration(seconds: 10));

	final bool Function(SocketBundle, String) registerClientCallback;

	@override
	Future<bool> onStepAction() async {
		final socket = socketBundle.socket;
		final reader = socketBundle.reader;

		// 第一步，接收验证的魔术字
		final magicLength = (await reader.readOneByte() & 0xFF) | ((await reader.readOneByte() & 0xFF) << 8);
		final magicWordBytes = socketBundle.decryptFunc(socketBundle, await reader.readBytes(length: magicLength));
		final magicWord = utf8.decode(magicWordBytes);
		if(magicWord != 'Transport') {
			// 验证失败
			return false;
		}

		// 第二步，接收 Client 传来的加密参数（比如 RSA 加密，对端的公钥证书就可以借此发送过来）
		// 但是参数长度限制在 2 个字节内，如果长度为 0，表示无需任何加密参数

		final encryptLength = (await reader.readOneByte() & 0xFF) | ((await reader.readOneByte() & 0xFF) << 8);
		if(encryptLength != 0) {
			final encryptBytes = socketBundle.decryptFunc(socketBundle, await reader.readBytes(length: encryptLength));
			socketBundle.analyzeEncryptParamsFunction(socketBundle, encryptBytes);
		}

		// 第三步，发送完成接收指令
		// 实际上是由 Server 端根据加密报文再发送一遍 "Transport"

		final magicBytes = await socketBundle.encryptFunc(socketBundle, utf8.encode('Transport'));
		var sendMagicLength = magicBytes.length;
		socket.add([sendMagicLength & 0xFF, (sendMagicLength >> 8) & 0xFF]);
		socket.add(magicBytes);
		await socket.flush();

		// 第四步，接收 Socket 类型
		// 0 - 控制 Socket
		// 1 - Request Socket
		// 2 - Response Socket

		// 第四步，也是最后一步，接收对端发送而来的 Client Id，查看是否可以注册
		final clientIdLength = await reader.readOneByte() & 0xFF;
		final clientIdBytes = socketBundle.decryptFunc(socketBundle, await reader.readBytes(length: clientIdLength));
		final clientId = utf8.decode(clientIdBytes);
		if(registerClientCallback(socketBundle, clientId)) {
			socketBundle.clientId = clientId;
			return true;
		}
		return false;
	}
}