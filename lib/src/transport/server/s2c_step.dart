import 'dart:convert';

import '../../step.dart';
import 'socket_bundle.dart';

/// Server 2 Client, hand shake resp
class HandShakeRespStep extends BaseSocketBundleStep<bool> {
	HandShakeRespStep(SocketBundle socketBundle, {this.registerClientCallback, this.checkClientCallback, this.constructRequestCallback, this.constructResponseCallback}) : super(socketBundle, Duration(seconds: 10));

	/// 注册 Client 回调
	final bool Function(SocketBundle, String) registerClientCallback;

	/// 检查是否存在对应 Client 回调
	final bool Function(String) checkClientCallback;

	/// 构建请求连接回调
	final bool Function(SocketBundle, int) constructRequestCallback;

	/// 构建响应连接回调
	final bool Function(SocketBundle, int) constructResponseCallback;

	/// Socket 握手
	/// 如果成功返回 true
	/// 失败返回 false 或抛出 exception
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

		// 第四步，接收 Socket 类型
		// 0 - 控制 Socket - 无需 ClientId
		// 1 - Request Socket - 无需 ClientId
		// 2 - Response Socket - 需要 ClientId
		final socketType = await reader.readOneByte() & 0xFF;
		if(socketType < 0 || socketType > 2) {
			// 类型错误
			return false;
		}
		socketBundle.socketType = socketType;

		// 第五步，根据 Socket 类型分开处理
		switch(socketType) {

			// 请求 Socket 类型
			case kSocketTypeRequest: {
				// 查询请求 Socket 对应 Client Id 是否存在
				if(!checkClientCallback(clientId)) {
					// 对应控制套接字已经不存在了，断开
					return false;
				}

				// 接收标记码，该码由 Server 指定，用来在请求/响应 Socket 之间建立联系
				final flagCode = await reader.readOneByte() & 0xFF;

				if(!constructRequestCallback(socketBundle, flagCode)) {
					// 匹配标记码失败，返回 false
					return false;
				}
				break;
			}

			// 响应 Socket 类型
			case kSocketTypeResponse: {
        // 接收对端发送而来的 Client Id，检查来源
        final clientIdLength = await reader.readOneByte() & 0xFF;
        final clientIdBytes = socketBundle.decryptFunc(socketBundle, await reader.readBytes(length: clientIdLength));
        final clientId = utf8.decode(clientIdBytes);
        socketBundle.clientId = clientId;

				// 查询响应 Socket 对应 Client Id 是否存在
				if(!checkClientCallback(clientId)) {
					// 对应控制套接字已经不存在了，断开
					return false;
				}

				// 接收标记码，该码由 Server 指定，用来在请求/响应 Socket 之间建立联系
				final flagCode = await reader.readOneByte() & 0xFF;

				if(!constructResponseCallback(socketBundle, flagCode)) {
					// 匹配标记码失败，返回 false
					return false;
				}
				break;
			}
		}

		// 第七步，发送建立成功响应
		socket.add([250]);
		await socket.flush();

		return true;
	}
}

