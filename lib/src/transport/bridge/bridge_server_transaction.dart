import 'dart:io';

import 'package:encrypt/encrypt_io.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:transport/src/encrypt/rsa.dart';
import 'package:transport/src/isolate_runner.dart';
import 'package:transport/src/socket_bundle.dart';
import 'package:transport/src/transport/bridge/bridge_cmd.dart';

import '../../log_interface.dart';
import '../../server.dart';

class BridgeServerTransaction extends ServerTransaction {

	BridgeServerTransaction({
		this.rsaPrivateKeyPath,
		String rsaMagicWord,
		LogInterface logInterface
	})
		: rsaMagicWord = rsaMagicWord ?? 'virtual-lightning.com',
			super(logInterface: logInterface);

	/// RSA Private key path
	final String rsaPrivateKeyPath;

	/// RSA Magic word
	final String rsaMagicWord;

	/// RSA Private key data
	RSAPrivateKey _privateKey;

	/// Control socket hand shake crypt type
	var _controlHandShakeEncryptType = 0;

	/// Control socket map
	/// If control socket hand shake success, will be cached in here
	final _controlSocketMap = <String, SocketBundle>{};

	/// Wait control socket response, socket will be cached in here ,
	/// time out 10 second.
	final _pendingSocketMap = <String, List<SocketBundle>>{};

	/// Init RSA Private key file
	/// Init Crypt type
	@override
	Future<void> onBeforeServerStart() async {
		if (rsaPrivateKeyPath != null) {
			_privateKey = await IsolateRunner.execute(
				rsaPrivateKeyPath,
				runner: parseKeyFromFile
			);
			_controlHandShakeEncryptType = 0x01;
			if (needLog) {
				logInfo('success load RSA Private key...');
			}
		}
		else {
			_controlHandShakeEncryptType = 0x00;
		}
	}

	/// Print server start
	@override
	Future<void> onAfterServerStarted() {
		if (needLog) {
			logInfo('Bridge server start. Listen on $localPort');
		}
		return super.onAfterServerStarted();
	}

	/// Print server closed
	@override
	Future<void> onAfterServerClosed() {
		if (needLog) {
			logInfo('Bridge server closed.');
		}
		return super.onAfterServerClosed();
	}

	/// Handle socket from server
	@override
	void handleSocket(Socket socket) async {
		// handshake, time out 20 seconds
		final socketBundle = SocketBundle(socket);
		try {
			await _handShake(socketBundle).timeout(const Duration(seconds: 20));
		}
		catch (e, stackTrace) {
			socketBundle.destroy();
			if (needLog) {
				logWrong('socket hand shake error. from ${socketBundle.address}');
				logError(e, stackTrace);
			}
		}
	}

	/// Handle socket hand shake
	Future<void> _handShake(SocketBundle socketBundle) async {
		// get socket type
		final type = await socketBundle.reader.readOneByte(timeOut: 2);
		switch (type) {
			case 0x00:
			// 00 - represent control socket
				await _handShakeForControlSocket(socketBundle);
				break;
			case 0x01:
			// 01 - represent request socket
				await _handShakeForControlSocket(socketBundle);
				break;
			default:
			// unknown crypt type
				socketBundle.destroy();
				if (needLog) {
					logWrong('unknown socket type \'0x${type.toRadixString(16)}\'. from ${socketBundle.address}');
				}
				return;
		}
	}

	/// Handle control socket hand shake
	Future<void> _handShakeForControlSocket(SocketBundle socketBundle) async {
		// get crypt type
		try {
			final cryptType = await socketBundle.reader.readOneByte(timeOut: 2);
			if (_controlHandShakeEncryptType != cryptType) {
				// crypt type not match, close socket
				socketBundle.destroy();
				if (needLog) {
					logWrong('control socket crypt type not match. from ${socketBundle.address}');
				}
				return;
			}

			// control socket topic
			String topic;

			switch (cryptType) {
			// 00 - represent no crypt
				case 0x00:
					final topicLength = await socketBundle.reader.readOneByte(timeOut: 2);
					topic = await socketBundle.reader.readString(length: topicLength, timeOut: 5);
					final mixKey = await socketBundle.reader.readOneByte(timeOut: 2);
					socketBundle.mixKey = mixKey;
					break;
			// 01 - represent RSA crypt
				case 0x01:
				// read base64 key length
					final base64Length = await socketBundle.reader.readOneByte(timeOut: 2);
					final base64String = await socketBundle.reader.readString(length: base64Length, timeOut: 5);
					var decodeStr = await RSAHandShakeEncrypt().decode(_privateKey, base64String);
					if (decodeStr.length <= rsaMagicWord.length) {
						// magic word not match
						socketBundle.destroy();
						if (needLog) {
							logWrong('control socket info not enough. from ${socketBundle.address}');
						}
						return;
					}

					final socketMagicWord = decodeStr.substring(0, rsaMagicWord.length);
					if (socketMagicWord != rsaMagicWord) {
						// magic word not match
						socketBundle.destroy();
						if (needLog) {
							logWrong('control socket rsa magic word not match. from ${socketBundle.address}, wrong word: ${socketMagicWord.length > 16 ? '${socketMagicWord.substring(0, 16)}...(length over 16 auto cut)' : socketMagicWord}');
						}
						return;
					}

					final topicLength = decodeStr.codeUnitAt(rsaMagicWord.length);
					topic = decodeStr.substring(rsaMagicWord.length + 1, topicLength);
					final mixKey = await socketBundle.reader.readOneByte(timeOut: 2);
					socketBundle.mixKey = mixKey;
					break;
				default:
				// unknown crypt type
					socketBundle.destroy();
					if (needLog) {
						logWrong('control socket unknown crypt type \'0x${cryptType.toRadixString(16)}\'. from ${socketBundle.address}');
					}
					return;
			}
			if (_controlSocketMap.containsKey(topic)) {
				socketBundle.destroy();
				if (needLog) {
					logWarn('reapeat control socket. topic: $topic, from ${socketBundle.address}');
				}
				return;
			}

			// send server hello to client
			BridgeCommand(cmdCode: 0x00, msgType: 0xFF).writeCommand(
				byteWriter: socketBundle.writer,
				mixKey: socketBundle.mixKey);

			// Build command stream, recv from client cmd
			BridgeCommandStream(mixKey: socketBundle.mixKey).wrapperControlSocket(socketBundle.reader.releaseStream()).listen((event) {
				if(socketBundle.cmdWaiter != null) {
					socketBundle.cmdWaiter(event);
				}
				switch (event.cmdCode) {
					case 0xFF:
						socketBundle.mixKey = event.message;
						break;
				}
			}, onError: (e, stackTrace) {
				if (needLog) {
					logWrong('control socket wrong cmd error. topic: $topic, from ${socketBundle.address}');
					logError(e, stackTrace);
				}
			}, onDone: () {
				logInfo('remove control socket. topic: $topic, from ${socketBundle.address}');
				_controlSocketMap.remove(topic);
			});

			// Add control socket into [_controlSocketMap]
			_controlSocketMap[topic] = socketBundle;
			if (needLog) {
				logInfo('add control socket. topic: $topic, from ${socketBundle.address}');
			}
		}
		catch (e, stackTrace) {
			if (needLog) {
				logWrong('control socket hand shake error. from ${socketBundle.address}');
				logError(e, stackTrace);
			}
		}
	}

	/// Handle request socket hand shake
	Future<void> _handShakeForRequestSocket(SocketBundle socketBundle) async {
		try {
			final topicLength = await socketBundle.reader.readOneByte(timeOut: 2);
			final topic = await socketBundle.reader.readString(length: topicLength, timeOut: 5);
			final controlSocket = _controlSocketMap[topic];
			if(controlSocket == null) {
				socketBundle.destroy();
				if(needLog) {
					logWrong('request socket connect illegal. from ${socketBundle.address}');
				}
				return;
			}

		}
		catch (e, stackTrace) {
			if (needLog) {
				logWrong('request socket hand shake error. from ${socketBundle.address}');
				logError(e, stackTrace);
			}
		}
	}
}