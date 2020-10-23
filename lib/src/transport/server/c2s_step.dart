import 'dart:convert';

import '../../step.dart';
import 'socket_bundle.dart';

/// Client 2 Server, hand shake req
class HandShakeReqStep extends BaseSocketBundleStep<bool> {
    HandShakeReqStep(SocketBundle socketBundle) : super(socketBundle, Duration(seconds: 10));

	@override
	Future<bool> onStepAction() async {
		final socket = socketBundle.socket;
		final reader = socketBundle.reader;

		// 第一步，发送魔术字
		final magicBytes = await socketBundle.encryptFunc(socketBundle, utf8.encode('Transport'));
		var length = magicBytes.length;
		socket.add([length & 0xFF, (length >> 8) & 0xFF]);
		socket.add(magicBytes);
		await socket.flush();

		// 第二步，发送加密配置
		final paramsBytes = await socketBundle.encryptParamsFunction();
		if(paramsBytes != null && paramsBytes.isNotEmpty) {
			length = paramsBytes.length;
			socket.add([length & 0xFF, (length >> 8) & 0xFF]);
			socket.add(paramsBytes);
			await socket.flush();
		}
		else {
			socket.add([0, 0]);
		}

		// 第三步，接收服务器发送过来的魔术字
		final magicLength = (await reader.readOneByte() & 0xFF) | ((await reader.readOneByte() & 0xFF) << 8);
		final magicWordBytes = socketBundle.decryptFunc(socketBundle, await reader.readBytes(length: magicLength));
		final magicWord = utf8.decode(magicWordBytes);
		if(magicWord != 'Transport') {
			// 验证失败
			return false;
		}


		// 第四步，发送 Client Id
		final clientIdBytes = await socketBundle.encryptFunc(socketBundle, utf8.encode(socketBundle.clientId));
		length = clientIdBytes.length;
		socket.add([length & 0xFF, (length >> 8) & 0xFF]);
		socket.add(clientIdBytes);
		await socket.flush();

		return true;

	}
}