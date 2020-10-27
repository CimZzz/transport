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

/// Client Command Sender
class ClientCommand {
	ClientCommand._();


	/// Send client command.
	///
	/// All client command  via this method to send, you can send custom message when
	/// you need by this method
	static Future<void> sendClientCommand(SocketBundle socketBundle, int commandType, {int cmdIdx, List<int> byteBuffer}) async {
		final bytesList = <int>[commandType & 0xFF];

		bytesList.add((cmdIdx ?? 0x00) & 0xFF);
		if(byteBuffer != null) {
			bytesList.addAll(byteBuffer);
		}
		await socketBundle.socket.flush();
	}


	/// Send heartbeat
	///
	///   0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7
	/// + - - - - - - - - - - - - - - - - +
	/// |      type      |    cmdIdx      |
	/// + - - - - - - - - - - - - - - - - +
	///
	/// type: int, 8 bits (1 bytes) , always 0x00
	///
	static Future<void> sendHeartbeatTick(SocketBundle socketBundle) async {
		await sendClientCommand(socketBundle, 0x00);
	}

	/// Send query client command
	///
	///   0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7
	/// + - - - - - - - - - - - - - - - - +
	/// |      type      |    cmdIdx      |
	/// + - - - - - - - - - - - - - - - - +
	///
	///
	/// type: int, 8 bits (1 bytes) , always 0x01
	/// cmdIdx: int, 8 bits (1 bytes) , command idx, use to match command req & res, 0 represent no-res req
	///
	static Future<void> sendQueryClientCommand(SocketBundle socketBundle, {int cmdIdx}) async {
		await sendClientCommand(socketBundle, 0x01, cmdIdx: cmdIdx);
	}


	/// Send request, open another port as local port
	///
	///   0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7
	/// + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
	/// |      type      |    cmdIdx     |             port               |
	/// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	/// |                            ipAddress                            |
	/// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	/// |  transportType |    length     |           clientId             |
	/// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	/// |                            clientId                             |
	/// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	/// |                               ...                               |
	/// + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
	///
	///
	/// type: int, 8 bits (1 bytes) , always 0x02
	/// cmdIdx: int, 8 bits (1 bytes) , command idx, use to match command req & res, 0 represent no-res req
	/// port: int, 16 bits (2 bytes) , via peer client, access specify port
	/// ipAddress: int, 32 bits (4 bytes) , via peer client, access specify ip address. always 0x7F00000000(127.0.0.1)
	/// transPort: int, 8 bits (1 bytes) , transport type, current only support tcp/ip(0x00)
	/// length: int, 8 bits (1 bytes) , client id length, 1 ~ 255
	///
	static Future<void> sendRequestCommand(SocketBundle socketBundle, {int cmdIdx, String clientId, int ipAddress, int port, int transportType}) async {
		final bytesList = <int>[];
		bytesList.add(port & 0xFF);
		bytesList.add((port >> 8) & 0xFF);
		bytesList.add(ipAddress & 0xFF);
		bytesList.add((ipAddress >> 8) & 0xFF);
		bytesList.add((ipAddress >> 16) & 0xFF);
		bytesList.add((ipAddress >> 24) & 0xFF);
		bytesList.add(transportType & 0xFF);
		final clientIdBytes = utf8.encode(clientId);
		bytesList.add(clientIdBytes.length & 0xFF);
		bytesList.addAll(clientIdBytes);
		await sendClientCommand(socketBundle, 0x02, cmdIdx: cmdIdx, byteBuffer: bytesList);
	}
}