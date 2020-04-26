import 'dart:io';

import 'package:encrypt/encrypt_io.dart';
import 'package:pointycastle/asymmetric/api.dart';
import '../../encrypt/rsa.dart';
import '../../isolate_runner.dart';
import '../../mix_key.dart';
import '../../log_interface.dart';
import '../../server.dart';
import '../../stream_transport.dart';
import 'bridge_cmd.dart';
import 'bridge_socket_bundle.dart';


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
	final _controlSocketMap = <String, BridgeSocketBundle>{};
	
	/// Response pending verify socket map
	final _pendingVerifyResSocketMap = <String,
		Map<String, BridgeSocketBundle>>{};
	
	/// Request pending verify socket map
	final _pendingVerifyReqSocketMap = <String,
		Map<String, BridgeSocketBundle>>{};
	
	/// Request pending socket map
	final _pendingSocketMap = <String, List<BridgeSocketBundle>>{};
	
	/// Add verified socket to pending socket map
	void _addPendingSocket(BridgeSocketBundle socketBundle) {
		final list = _pendingSocketMap.putIfAbsent(
			socketBundle.slot.subscribeTopic, () => []);
		list.add(socketBundle);
		
		// Remove from pending list when it destroy
		socketBundle.slot.onDestroy = (bundle) {
			final list = _pendingSocketMap[socketBundle.slot.subscribeTopic];
			if (list != null) {
				list.remove(bundle);
				if (list.isEmpty) {
					_pendingSocketMap.remove(socketBundle.slot.subscribeTopic);
				}
			}
		};
		// wait 10 second, if not match response, remove it
		socketBundle.wait(10, onTimeOut: () {
			socketBundle.destroy();
			if (needLog) {
				logWarn('client not response, closed. topic: ${socketBundle.slot
					.topic}, address:${socketBundle.address}');
			}
		});
	}
	
	/// Fetch and remote from pending socket map
	BridgeSocketBundle _pickPendingSocket(String topic) {
		final list = _pendingSocketMap[topic];
		if (list != null && list.isNotEmpty) {
			final socketBundle = list.removeAt(0);
			// Remove destroy callback and countdown
			socketBundle.slot.onDestroy = null;
			socketBundle.cancelWait();
			if (list.isEmpty) {
				_pendingSocketMap.remove(topic);
			}
			return socketBundle;
		}
		return null;
	}
	
	/// Add unverified request socket to pending verify request socket map
	void _addPendingRequest(BridgeSocketBundle socketBundle) {
		final map = _pendingVerifyReqSocketMap.putIfAbsent(
			socketBundle.slot.topic, () => {});
		map[socketBundle.slot.reqKey] = socketBundle;
		
		// Remove from pending list when it destroy
		socketBundle.slot.onDestroy = (bundle) {
			final map = _pendingVerifyResSocketMap[socketBundle.slot.topic];
			if (map != null) {
				map.remove(bundle.slot.reqKey);
			}
		};
		// Wait 10 second
		socketBundle.wait(10, onTimeOut: () {
			socketBundle.destroy();
			if (needLog) {
				logWarn(
					'request verify time out, closed. topic: ${socketBundle.slot
						.topic}, address:${socketBundle.address}');
			}
		});
	}
	
	/// Fetch and remote from pending verify request socket map
	BridgeSocketBundle _pickPendingRequest(String topic, String reqKey) {
		final map = _pendingVerifyReqSocketMap[topic];
		if (map != null) {
			final socketBundle = map.remove(reqKey);
			if (socketBundle != null) {
				// Remove destroy callback and countdown
				socketBundle.slot.onDestroy = null;
				socketBundle.cancelWait();
				if (map.isEmpty) {
					_pendingVerifyReqSocketMap.remove(topic);
				}
			}
			return socketBundle;
		}
		return null;
	}
	
	/// Add unverified response socket to pending verify request socket map
	void _addPendingResponse(BridgeSocketBundle socketBundle) {
		final map = _pendingVerifyResSocketMap.putIfAbsent(
			socketBundle.slot.topic, () => {});
		map[socketBundle.slot.reqKey] = socketBundle;
		
		// Remove from pending list when it destroy
		socketBundle.slot.onDestroy = (bundle) {
			final map = _pendingVerifyResSocketMap[socketBundle.slot.topic];
			if (map != null) {
				map.remove(bundle.slot.reqKey);
			}
		};
		// Wait 10 second
		socketBundle.wait(10, onTimeOut: () {
			socketBundle.destroy();
			if (needLog) {
				logWarn('response verify time out, closed. topic: ${socketBundle
					.slot.topic}, address:${socketBundle.address}');
			}
		});
	}
	
	/// Fetch and remote from pending verify response socket map
	BridgeSocketBundle _pickPendingResponse(String topic, String reqKey) {
		final map = _pendingVerifyResSocketMap[topic];
		if (map != null) {
			final socketBundle = map.remove(reqKey);
			if (socketBundle != null) {
				// Remove destroy callback and countdown
				socketBundle.slot.onDestroy = null;
				socketBundle.cancelWait();
				if (map.isEmpty) {
					_pendingVerifyResSocketMap.remove(topic);
				}
			}
			return socketBundle;
		}
		return null;
	}
	
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
		// handshake, time out 15 seconds
		final socketBundle = BridgeSocketBundle(socket);
		try {
			await _handShake(socketBundle).timeout(const Duration(seconds: 15));
		}
		catch (e, stackTrace) {
			socketBundle.destroy();
			if (needLog) {
				logWrong(
					'socket hand shake error. from ${socketBundle.address}');
				logError(e, stackTrace);
			}
		}
	}
	
	/// Handle socket hand shake
	Future<void> _handShake(BridgeSocketBundle socketBundle) async {
		// get socket type
		final type = await socketBundle.reader.readOneByte(timeOut: 2);
		switch (type) {
			case 0x00:
			// 00 - represent control socket
				await _handShakeForControlSocket(socketBundle);
				break;
			case 0x01:
			// 01 - represent request socket
				await _handShakeForRequestSocket(socketBundle);
				break;
			case 0x02:
			// 02 - represent response socket
				await _handShakeForResponseSocket(socketBundle);
				break;
			default:
			// unknown crypt type
				socketBundle.destroy();
				if (needLog) {
					logWrong('unknown socket type \'0x${type.toRadixString(
						16)}\'. from ${socketBundle.address}');
				}
				return;
		}
	}
	
	/// Handle control socket hand shake
	Future<void> _handShakeForControlSocket(BridgeSocketBundle socketBundle) async {
		// get crypt type
		try {
			final cryptType = await socketBundle.reader.readOneByte(timeOut: 2);
			if (_controlHandShakeEncryptType != cryptType) {
				// crypt type not match, close socket
				socketBundle.destroy();
				if (needLog) {
					logWrong(
						'control socket crypt type not match. from ${socketBundle
							.address}');
				}
				return;
			}
			
			// control socket topic
			String topic;
			var mixKey = 0;
			bool doTransport;
			
			switch (cryptType) {
			// 00 - represent no crypt
				case 0x00:
					final topicLength = await socketBundle.reader.readOneByte(
						timeOut: 2);
					topic = await socketBundle.reader.readString(
						length: topicLength, timeOut: 5);
					mixKey = await socketBundle.reader.readOneInt(timeOut: 2);
					doTransport = (await socketBundle.reader.readOneByte(timeOut: 2)) == 0x01;
					break;
			// 01 - represent RSA crypt
				case 0x01:
				// read base64 key length
					final base64Length = await socketBundle.reader.readOneInt(
						timeOut: 2);
					final base64String = await socketBundle.reader.readString(
						length: base64Length, timeOut: 5);
					var decodeStr = await RSAHandShakeEncrypt().decode(
						_privateKey, base64String);
					if (decodeStr.length <= rsaMagicWord.length) {
						// magic word not match
						socketBundle.destroy();
						if (needLog) {
							logWrong(
								'control socket info not enough. from ${socketBundle
									.address}');
						}
						return;
					}
					
					final socketMagicWord = decodeStr.substring(
						0, rsaMagicWord.length);
					if (socketMagicWord != rsaMagicWord) {
						// magic word not match
						socketBundle.destroy();
						if (needLog) {
							logWrong(
								'control socket rsa magic word not match. from ${socketBundle
									.address}, wrong word: ${socketMagicWord
									.length > 16
									? '${socketMagicWord.substring(
									0, 16)}...(length over 16 auto cut)'
									: socketMagicWord}');
						}
						return;
					}
					
					final topicLength = decodeStr[rsaMagicWord.length]
						.codeUnits[0];
					topic = decodeStr.substring(rsaMagicWord.length + 1,
						rsaMagicWord.length + 1 + topicLength);
					mixKey = await socketBundle.reader.readOneInt(timeOut: 2);
					doTransport = (await socketBundle.reader.readOneByte(timeOut: 2)) == 0x01;
					break;
				default:
				// unknown crypt type
					socketBundle.destroy();
					if (needLog) {
						logWrong(
							'control socket unknown crypt type \'0x${cryptType
								.toRadixString(16)}\'. from ${socketBundle
								.address}');
					}
					return;
			}
			if (_controlSocketMap.containsKey(topic)) {
				socketBundle.destroy();
				if (needLog) {
					logWarn(
						'reapeat control socket. topic: $topic, from ${socketBundle
							.address}');
				}
				return;
			}
			
			socketBundle.slot.topic = topic;
			socketBundle.slot.mixKey = MixKey(mixKey);
			socketBundle.slot.doTransport = doTransport;
			
			// Build command stream, recv from client
			socketBundle.watchStream(transformBridgeStream<BridgeClientCommand>(
				dataStream: socketBundle.reader.releaseStream(),
				mixKey: socketBundle.slot.mixKey
			).listen((event) async {
				await handleBridgeClientCommand(socketBundle, event);
			}, onError: (e, stackTrace) {
				if (needLog) {
					logWrong(
						'control socket command error $e. topic: $topic, from ${socketBundle
							.address}');
					logError(e, stackTrace);
				}
			}, onDone: () {
				_controlSocketMap.remove(topic)?.destroy();
				if (needLog) {
					logInfo(
						'remove control socket. topic: $topic, from ${socketBundle
							.address}');
				}
			}));
			
			// Add control socket into [_controlSocketMap]
			_controlSocketMap[topic] = socketBundle;
			if (needLog) {
				logInfo('add control socket. topic: $topic, from ${socketBundle
					.address}');
			}
			
			// send server hello to client
			socketBundle.writeCommand(BridgeServerCommand(
				code: BridgeServerCode.ServerHello
			));
		}
		catch (e, stackTrace) {
			if (needLog) {
				logWrong('control socket hand shake error. from ${socketBundle
					.address}');
				logError(e, stackTrace);
			}
		}
	}
	
	/// Handle request socket hand shake
	Future<void> _handShakeForRequestSocket(BridgeSocketBundle socketBundle) async {
		try {
			final topicLength = await socketBundle.reader.readOneByte(
				timeOut: 2);
			final topic = await socketBundle.reader.readString(
				length: topicLength, timeOut: 5);
			final controlSocket = _controlSocketMap[topic];
			if (controlSocket == null) {
				socketBundle.destroy();
				if (needLog) {
					logWrong(
						'request socket connect illegal. from ${socketBundle
							.address}');
				}
				return;
			}
			controlSocket.addChild(socketBundle);
			final reqKeyLength = await socketBundle.reader.readOneByte(
				timeOut: 2, mixKey: controlSocket.slot.mixKey);
			final reqKey = await socketBundle.reader.readString(
				length: reqKeyLength,
				timeOut: 5,
				mixKey: controlSocket.slot.mixKey);
			socketBundle.slot.topic = topic;
			socketBundle.slot.reqKey = reqKey;
			socketBundle.slot.isRequest = true;
			// add to request map, wait control socket reply
			_addPendingRequest(socketBundle);
			// found control socket, send confirm cmd
			controlSocket.writeCommand(BridgeServerCommand(
				code: BridgeServerCode.RequestSocketConfirm,
				message: reqKey
			));
			if (needLog) {
				logInfo('receive request socket, wait verifying. topic: $topic, from ${socketBundle.address}');
			}
		}
		catch (e, stackTrace) {
			if (needLog) {
				logWrong('request socket hand shake error. from ${socketBundle.address}');
				logError(e, stackTrace);
			}
		}
	}
	
	/// Handle response socket hand shake
	Future<void> _handShakeForResponseSocket(BridgeSocketBundle socketBundle) async {
		try {
			final topicLength = await socketBundle.reader.readOneByte(
				timeOut: 2);
			final topic = await socketBundle.reader.readString(
				length: topicLength, timeOut: 5);
			final controlSocket = _controlSocketMap[topic];
			if (controlSocket == null) {
				socketBundle.destroy();
				if (needLog) {
					logWrong('response socket connect illegal. from ${socketBundle.address}');
				}
				return;
			}
			controlSocket.addChild(socketBundle);
			
			final reqKeyLength = await socketBundle.reader.readOneByte(
				mixKey: controlSocket.slot.mixKey, timeOut: 2);
			final reqKey = await socketBundle.reader.readString(
				length: reqKeyLength,
				mixKey: controlSocket.slot.mixKey,
				timeOut: 5);
			socketBundle.slot.topic = topic;
			socketBundle.slot.reqKey = reqKey;
			socketBundle.slot.isRequest = false;
			// found control socket, send confirm cmd
			controlSocket.writeCommand(BridgeServerCommand(
				code: BridgeServerCode.ResponseSocketConfirm,
				message: reqKey
			));
			// add to response map, wait control socket reply
			_addPendingResponse(socketBundle);
			if (needLog) {
				logInfo('receive response socket, wait verifying. topic: $topic, from ${socketBundle.address}');
			}
		}
		catch (e, stackTrace) {
			if (needLog) {
				logWrong('response socket hand shake error. from ${socketBundle
					.address}');
				logError(e, stackTrace);
			}
		}
	}
	
	/// Handle control socket command
	Future<void> handleBridgeClientCommand(BridgeSocketBundle socketBundle,
		BridgeClientCommand command) async {
		switch (command.code) {
			case BridgeClientCode.MixKey:
				socketBundle.writeCommand(BridgeServerCommand(
					code: BridgeServerCode.MixKey,
					message: command.message
				));
				socketBundle.slot.mixKey = MixKey(command.message);
				if (needLog) {
					logInfo('mixKey changed. topic: ${socketBundle.slot.topic}, from ${socketBundle.address}');
				}
				break;
			
			case BridgeClientCode.RequestSocketReplySuccess:
				final reqSocketBundle = _pickPendingRequest(socketBundle.slot.topic, command.message);
				if (reqSocketBundle == null) {
					// request socket had destroy...
					return;
				}
				// Reply success
				try {
					final topicLength = await reqSocketBundle.reader.readOneByte(
						timeOut: 2,
						mixKey: socketBundle.slot.mixKey
					);
					final topic = await reqSocketBundle.reader.readString(
						length: topicLength,
						timeOut: 5,
						mixKey: socketBundle.slot.mixKey
					);
					// find correspond control socket
					final corControlSocket = _controlSocketMap[topic];
					if (corControlSocket == null) {
						socketBundle.writeCommand(BridgeServerCommand(
							code: BridgeServerCode.RequestUnknownTopic
						));
						reqSocketBundle.destroy();
						if (needLog) {
							logWrong('request socket don\'t found corresponding topic. topic: ${reqSocketBundle.slot.topic}, '
								'from ${reqSocketBundle.address} specify topic: $topic');
						}
						return;
					}
					if(corControlSocket.slot.doTransport != true) {
						// destroy request, because control socket does not support transport request
						reqSocketBundle.destroy();
						if (needLog) {
							logWarn('control socket doesn\'t support transport. topic: ${reqSocketBundle.slot.topic}, '
								'from ${reqSocketBundle.address} specify topic: $topic');
						}
						return;
					}
					// add to pending socket map, wait response socket
					reqSocketBundle.slot.subscribeTopic = topic;
					_addPendingSocket(reqSocketBundle);
					if (needLog) {
						logInfo('request socket verify success.. topic: ${reqSocketBundle.slot.topic},'
							' from ${reqSocketBundle.address}');
					}
					corControlSocket.writeCommand(BridgeServerCommand(
						code: BridgeServerCode.NeedResponse
					));
				}
				catch (e, stackTrace) {
					reqSocketBundle.destroy();
					if (needLog) {
						logWrong(
							'request socket failed to verify. topic: ${reqSocketBundle.slot.topic}, '
								'from ${reqSocketBundle.address}');
						logError(e, stackTrace);
					}
				}
				break;
			
			case BridgeClientCode.RequestSocketReplyFailure:
				final reqSocketBundle = _pickPendingRequest(socketBundle.slot.topic, command.message);
				if (reqSocketBundle == null) {
					// request socket had destroy...
					return;
				}
				
				// Reply failure
				reqSocketBundle.destroy();
				if (needLog) {
					logWrong('request socket failed to verify. topic: ${reqSocketBundle.slot.topic},'
						' from ${reqSocketBundle.address}');
				}
				break;
				
			case BridgeClientCode.ResponseSocketReplySuccess:
				final resSocketBundle = _pickPendingResponse(
					socketBundle.slot.topic,
					command.message
				);
				
				if (resSocketBundle == null) {
					// response socket had destroy...
					return;
				}
				
				// Reply success
				final reqSocketBundle = _pickPendingSocket(resSocketBundle.slot.topic);
				
				if (reqSocketBundle == null) {
					resSocketBundle.destroy();
					if (needLog) {
						logWrong('response socket don\'t found request socket. topic: '
							'${resSocketBundle.slot.topic}, from ${resSocketBundle.address}');
					}
					return;
				}
				final requestControlSocket = _controlSocketMap[reqSocketBundle.slot.topic];
				final newMixKey = MixKey.random();

				requestControlSocket.writeCommand(BridgeServerCommand(
					code: BridgeServerCode.TransportRequest,
					message: [reqSocketBundle.slot.reqKey, newMixKey.baseKey.toString()]
				));
				socketBundle.writeCommand(BridgeServerCommand(
					code: BridgeServerCode.TransportResponse,
					message: <String>[resSocketBundle.slot.reqKey, newMixKey.baseKey.toString()],
				));
				_transportSocket(reqSocketBundle, resSocketBundle);
				break;

			case BridgeClientCode.ResponseSocketReplyFailure:
				final resSocketBundle = _pickPendingResponse(
					socketBundle.slot.topic,
					command.message
				);
				
				if (resSocketBundle == null) {
					// response socket had destroy...
					return;
				}
				
				// Reply failure
				resSocketBundle.destroy();
				if (needLog) {
					logWrong('response socket failed to verify. topic: ${resSocketBundle.slot.topic},'
						' from ${resSocketBundle.address}');
				}
				break;
			default:
			// unreachable
				break;
		}
	}
	
	/// Transport request socket and response socket
	void _transportSocket(BridgeSocketBundle requestBundle, BridgeSocketBundle responseBundle) {
		if (needLog) {
			logInfo('transporting ${requestBundle.slot.topic} and ${responseBundle.slot.topic}');
		}
		
		// create request transport
		final requestTransport = StreamTransport(
			requestBundle.reader.releaseStream(),
			bindData: requestBundle,
			streamDone: (srcTransport, otherTransport) {
				srcTransport.slot.destroy();
				otherTransport?.destroy();
			},
			recvStreamData: (srcTransport, List<int> data) {
				requestBundle.socket.add(data);
				return;
			},
			streamError: (transport, e, [stackTrace]) {
				if (needLog) {
					logWrong('request socket error... $e');
					logError(e, stackTrace);
				}
			}
		);
		
		// create response transport
		final responseTransport = StreamTransport(
			responseBundle.reader.releaseStream(),
			bindData: responseBundle,
			streamDone: (transport, otherTransport) {
				transport.slot.destroy();
				otherTransport?.destroy();
			},
			recvStreamData: (transport, List<int> data) {
				responseBundle.socket.add(data);
				return;
			},
			streamError: (transport, e, [stackTrace]) {
				if (needLog) {
					logWrong('response socket error... $e');
					logError(e, stackTrace);
				}
			}
		);
		
		requestTransport.transportToTransport(responseTransport);
		responseTransport.transportToTransport(requestTransport);
	}
	
}