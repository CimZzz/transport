import 'dart:async';

import 'package:encrypt/encrypt.dart';
import 'package:encrypt/encrypt_io.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:transport/src/buffer_reader.dart';
import 'package:transport/src/console_log_interface.dart';
import 'package:transport/src/encrypt/rsa.dart';
import 'package:transport/src/isolate_runner.dart';
import 'package:transport/src/server.dart';
import 'package:transport/src/stream_reader.dart';
import 'package:transport/src/transport/proxy/proxy_transaction.dart';



int readOneInt({bool bigEndian = true, int timeOut}) {
	var list = [0x00, 0x00, 0x12, 0x34];
	bigEndian ??= true;
	if(bigEndian) {
		return ((list[0] & 0xFF) << 24)
		| ((list[1] & 0xFF) << 16)
		| ((list[2] & 0xFF) << 8)
		| ((list[3] & 0xFF));
	}
	else {
		return ((list[3] & 0xFF) << 24)
		| ((list[2] & 0xFF) << 16)
		| ((list[1] & 0xFF) << 8)
		| ((list[0] & 0xFF));
	}
}

Future<RSAPrivateKey> parseKey(String path) async {
	return await parseKeyFromFile<RSAPrivateKey>(path);
}

void main() async {
//	print(readOneInt(bigEndian: false).toRadixString(16));

//	final publicKey = await parseKeyFromFile<RSAPublicKey>('/Users/wangyanxiong/Documents/IDEAProject/transport/rsa_public_key.pem');
//	final privKey = await parseKeyFromFile<RSAPrivateKey>('/Users/wangyanxiong/Documents/IDEAProject/transport/rsa_private_key.pem');
	final privKey = await IsolateRunner.execute<String, RSAPrivateKey>('/Users/wangyanxiong/Documents/IDEAProject/transport/rsa_private_key.pem',
			runner: parseKeyFromFile);


	final a = 'dVVJVdaEdOvUcqT7LZFWJI+GKuTEaFcmfIEq7sPseZ71XZ++IroJFXshz09L5KHU2eAC/cGv2Ijg+cNdEQVJ/z2OiFXrq7LKPrN/anWOB6Twoav13cHcou/Yv1afy8cHpcHQcPFX4uxg6NfDvlSHMyTRVh7bCRNYCNoPviU+EF24MuMjNtuuHEY9FpEmQtWcEm9DAEssdBDLOaGiH5A6Vn4nTPk4zg0jPqzeloojrwQ7jVErpunIh6sP66MNnNPX07obFtkCQYlFHHm5TjCqF8q6fH0Wl4xPIebPyiGtAHMiKKjfg68Nwba3tuVE6jjKzOuuFYu2QBBg7A8U63cICQ==';

	print(await RSAHandShakeEncrypt().decode(privKey, a)); // Lorem ipsum dolor sit amet, consectetur adipiscing elit
//	TransportServer(
//		localPort: 9999,
//		transaction: ProxyTransaction(
//			logInterface: const ConsoleLogInterface(),
//			remoteAddress: 'virtual-lightning.com',
//			remotePort: 80
//		)
//	)
//	..startServer();
}