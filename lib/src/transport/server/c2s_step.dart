import 'dart:convert';

import '../../step.dart';
import 'socket_bundle.dart';

/// Client 2 Server, hand shake req
class HandShakeReqStep extends BaseSocketBundleStep<bool> {
    HandShakeReqStep(SocketBundle socketBundle, {this.socketType, this.flagCode}) : super(socketBundle, Duration(seconds: 10));

    /// Socket 类型
    final int socketType;
    final int flagCode;


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

		// 第四步，写入 Socket 类型
		// 0 - 控制 Socket
		// 1 - Request Socket
		// 2 - Response Socket
		if(socketType < 0 || socketType > 2) {
			// 类型错误
			return false;
		}
		socket.add([socketType]);

		// 第五步，发送 Client Id
		final clientIdBytes = await socketBundle.encryptFunc(socketBundle, utf8.encode(socketBundle.clientId));
		length = clientIdBytes.length;
		socket.add([length & 0xFF, (length >> 8) & 0xFF]);
		socket.add(clientIdBytes);
		await socket.flush();

		// 第六步，根据 Socket 类型分开处理写入数据
		switch(socketType) {
			// 控制 Socket 类型
			case kSocketTypeControl: {
				// 无需写入额外信息
				break;
			}

			// 请求 Socket 类型
			case kSocketTypeRequest: {
				socket.add([flagCode & 0xFF]);
				await socket.flush();
				break;
			}

			// 响应 Socket 类型
			case kSocketTypeResponse: {
				socket.add([flagCode & 0xFF]);
				await socket.flush();
				break;
			}
		}

		// 第七步，等待 Server 响应
		final respCode = await reader.readOneByte() & 0xFF;
		return respCode == 250;

	}
}