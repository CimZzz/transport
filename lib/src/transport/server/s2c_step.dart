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
		final socketType = await reader.readOneByte() & 0xFF;
		if(socketType < 0 || socketType > 2) {
			// 类型错误
			return false;
		}
		socketBundle.socketType = socketType;

		// 第五步，接收对端发送而来的 Client Id，检查来源
		final clientIdLength = await reader.readOneByte() & 0xFF;
		final clientIdBytes = socketBundle.decryptFunc(socketBundle, await reader.readBytes(length: clientIdLength));
		final clientId = utf8.decode(clientIdBytes);
		socketBundle.clientId = clientId;

		// 第六步，根据 Socket 类型分开处理
		switch(socketType) {
			// 控制 Socket 类型
			case kSocketTypeControl: {
				// 绑定控制套接字
				if(!registerClientCallback(socketBundle, clientId)) {
					// 绑定失败，返回 false
					return false;
				}
				break;
			}

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

/// Bridge Command
class BridgeCommand {
	BridgeCommand._();

	/// Send heartbeat
	///
	///   0 1 2 3 4 5 6 7
	/// + - - - - - - - -
	/// |      type      |
	/// + - - - - - - - -
	///
	/// type: int, 8 bits (1 bytes) , always 0x00
	///
	Future<void> sendHeartbeatTick(SocketBundle socketBundle) async {
		socketBundle.socket.add([0x00]);
		await socketBundle.socket.flush();
	}

	/// When control socket ask for another control socket, via server
	/// send request transfer.
	///
	///
	///   0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7
	/// + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
	/// |      type      |   replyIdx    |             port               |
	/// + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
	///
	/// type: int, 8 bits (1 bytes) , always 0x02
	/// replyIdx: int, 8 bits (1 bytes) , reply idx, use to match command req & res
	/// port: int, 16 bits (2 bytes) , peer client want to access specify port
	///
	Future<void> sendRequestTransfer(SocketBundle socketBundle, int port) async {
		final bytesList = <int>[];
		bytesList.add(0x01);
		bytesList.add(port & 0xFF);
		bytesList.add((port >> 8) & 0xFF);
		socketBundle.socket.add(bytesList);
		await socketBundle.socket.flush();
	}
}
