import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:encrypt/encrypt_io.dart';
import 'package:pointycastle/asymmetric/api.dart';
import '../../encrypt/rsa.dart';
import '../../isolate_runner.dart';
import '../../log_interface.dart';
import '../../mix_key.dart';
import '../../server.dart';
import '../../stream_transport.dart';
import 'bridge_cmd.dart';
import 'bridge_socket_bundle.dart';


class BridgeClientTransaction extends ServerTransaction {
	
	BridgeClientTransaction({
		LogInterface logInterface,
		this.topic,
		this.remoteTopic,
		String transportAddress,
		this.transportPort,
		this.bridgeAddress,
		this.bridgePort,
		this.rsaPublicKeyPath,
		String rsaMagicWord,
	})
		: transportAddress = transportAddress ?? '127.0.0.1',
			rsaMagicWord = rsaMagicWord ?? 'virtual-lightning.com',
			super(logInterface: logInterface);
	
	/// Client topic
	final String topic;
	
	/// Remote topic
	final String remoteTopic;
	
	/// Transport address
	final String transportAddress;
	
	/// Transport port
	final int transportPort;
	
	/// Bridge server address
	final String bridgeAddress;
	
	/// Bridge server port
	final int bridgePort;
	
	/// RSA Public key path
	final String rsaPublicKeyPath;
	
	/// RSA Magic word
	final String rsaMagicWord;
	
	/// RSA Private key data
	RSAPublicKey _publicKey;
	
	/// Control socket hand shake crypt type
	var _controlHandShakeEncryptType = 0;
	
	/// Control socket
	BridgeSocketBundle _controlSocket;
	
	/// Whether control socket connected
	var _isControlConnected = false;
	
	/// Mix key timer
	Timer _mixKeyTimer;
	
	/// As Socket key
	var _keyCode = 0;
	
	/// Request socket and Response socket verify map
	final _pendingVerifySocketMap = <String, BridgeSocketBundle>{};
	
	/// Request socket and Response socket transport map
	final _pendingTransportSocketMap = <String, BridgeSocketBundle>{};
	
	/// Add unverified socket to pending verify socket map
	void _addPendingVerifySocket(BridgeSocketBundle socketBundle) {
		_pendingVerifySocketMap[socketBundle.slot.reqKey] = socketBundle;
		
		// Remove from pending list when it destroy
		socketBundle.slot.onDestroy = (bundle) {
			_pendingVerifySocketMap.remove(bundle.slot.reqKey);
		};
		// Wait 10 second
		socketBundle.wait(10, onTimeOut: () {
			socketBundle.destroy();
			if (needLog) {
				logWrong('socket wait verify time out, closed.');
			}
		});
	}
	
	/// Fetch and remote from pending verify socket map
	BridgeSocketBundle _pickPendingVerifySocket(String reqKey) {
		final socketBundle = _pendingVerifySocketMap.remove(reqKey);
		socketBundle?.slot?.onDestroy = null;
		socketBundle?.cancelWait();
		return socketBundle;
	}
	
	/// Add un-transport socket to pending transport socket map
	void _addPendingTransportSocket(BridgeSocketBundle socketBundle) {
		_pendingTransportSocketMap[socketBundle.slot.reqKey] = socketBundle;
		
		// Remove from pending list when it destroy
		socketBundle.slot.onDestroy = (bundle) {
			_pendingTransportSocketMap.remove(bundle.slot.reqKey);
		};
		// Wait 10 second
		socketBundle.wait(10, onTimeOut: () {
			socketBundle.destroy();
			if (needLog) {
				logWrong('socket wait transport time out, closed.');
			}
		});
	}
	
	/// Fetch and remote from pending transport socket map
	BridgeSocketBundle _pickPendingTransportSocket(String reqKey) {
		final socketBundle = _pendingTransportSocketMap.remove(reqKey);
		socketBundle?.slot?.onDestroy = null;
		socketBundle?.cancelWait();
		return socketBundle;
	}
	
	
	/// Init RSA Private key file
	/// Init Crypt type
	/// Connect bridge server
	@override
	Future<void> onBeforeServerStart() async {
		if (rsaPublicKeyPath != null) {
			_publicKey = await IsolateRunner.execute(
				rsaPublicKeyPath,
				runner: parseKeyFromFile
			);
			_controlHandShakeEncryptType = 0x01;
			if (needLog) {
				logInfo('success load RSA Public key...');
			}
		}
		else {
			_controlHandShakeEncryptType = 0x00;
		}
		if (topic.length > 0xFF) {
			throw Exception('topic over length, must less than 255');
		}
	}
	
	/// Print server start
	@override
	Future<void> onAfterServerStarted() {
		if (needLog) {
			logInfo('Bridge server start. Listen on $localPort');
		}
		_connectControlSocket();
		return super.onAfterServerStarted();
	}
	
	/// Close control socket
	/// Print server closed
	@override
	Future<void> onAfterServerClosed() {
		_destroyControlSocket();
		if (needLog) {
			logInfo('Bridge server closed.');
		}
		return super.onAfterServerClosed();
	}
	
	@override
	void handleSocket(Socket socket) {
		// Recv local socket
		if (!_isControlConnected) {
			socket.destroy();
			if (needLog) {
				logWrong('control socket not connect yet, block socket');
			}
			return;
		}
		_connectRequestSocket(socket);
	}
	
	/// Connect request socket to bridge server
	Future<void> _connectRequestSocket(Socket socket) async {
		BridgeSocketBundle requestSocket;
		try {
			requestSocket = BridgeSocketBundle(await Socket.connect(bridgeAddress, bridgePort));
			if (!_isControlConnected) {
				// control socket disconnected, destroy socket
				socket.destroy();
				requestSocket.destroy();
				return;
			}
			_controlSocket.addChild(requestSocket);
			// add socket to slot
			requestSocket.slot.proxySocket = socket;
			// when request socket close, the local socket also close too
			final topicLength = topic.codeUnits.length;
			final remoteTopicLength = remoteTopic.codeUnits.length;
			// request socket request key(unique)
			final reqKey = _genSocketKey();
			final reqKeyLength = reqKey.codeUnits.length;
			
			requestSocket.slot.isRequest = true;
			requestSocket.slot.reqKey = reqKey;
			// request socket flag
			requestSocket.writer.writeByte(0x01);
			requestSocket.writer.writeByte(topicLength);
			requestSocket.writer.writeString(topic);
			requestSocket.writer.writeByte(reqKeyLength, mixKey: _controlSocket.slot.mixKey);
			requestSocket.writer.writeString(reqKey, mixKey: _controlSocket.slot.mixKey);
			requestSocket.writer.writeByte(remoteTopicLength, mixKey: _controlSocket.slot.mixKey);
			requestSocket.writer.writeString(remoteTopic, mixKey: _controlSocket.slot.mixKey);
			
			// wait server verify, time out 10 seconds
			_addPendingVerifySocket(requestSocket);
			requestSocket.writer.flush();
		}
		catch (e, stackTrace) {
			socket.destroy();
			requestSocket?.destroy();
			if (needLog) {
				logWrong('request socket occur error $e.');
				logError(e, stackTrace);
			}
		}
	}
	
	/// Connect response socket to bridge server
	Future<void> _connectResponseSocket() async {
		BridgeSocketBundle responseSocket;
		try {
			responseSocket = BridgeSocketBundle(await Socket.connect(bridgeAddress, bridgePort));
			if (!_isControlConnected) {
				// control socket disconnected, destroy socket
				responseSocket.destroy();
				return;
			}
			final socket = await Socket.connect(transportAddress, transportPort);
			// add socket to slot
			responseSocket.slot.proxySocket = socket;
			if (!_isControlConnected) {
				// control socket disconnected, destroy socket
				responseSocket.destroy();
				return;
			}
			_controlSocket.addChild(responseSocket);
			
			final topicLength = topic.codeUnits.length;
			final reqKey = _genSocketKey();
			final reqKeyLength = reqKey.codeUnits.length;
			responseSocket.slot.isRequest = false;
			responseSocket.slot.reqKey = reqKey;
			// response socket flag
			responseSocket.writer.writeByte(0x02);
			responseSocket.writer.writeByte(topicLength);
			responseSocket.writer.writeString(topic);
			responseSocket.writer.writeByte(reqKeyLength, mixKey: _controlSocket.slot.mixKey);
			responseSocket.writer.writeString(reqKey, mixKey: _controlSocket.slot.mixKey);
			
			// wait server verify, time out 10 seconds
			_addPendingVerifySocket(responseSocket);
			responseSocket.writer.flush();
		}
		catch (e, stackTrace) {
			responseSocket?.destroy();
			if (needLog) {
				logWrong('response socket occur error $e.');
				logError(e, stackTrace);
			}
		}
	}
	
	/// Connect to remote bridge server
	Future<void> _connectControlSocket() async {
		var isFinished = false;
		try {
			if (!isRunning) {
				return;
			}
			_controlSocket = BridgeSocketBundle(await Socket.connect(bridgeAddress, bridgePort));
			// gen random mix key
			_controlSocket.slot.mixKey = MixKey(Random().nextInt(0xFFFFFFFF));
			// connect success, try server hand shake
			// control socket flag
			_controlSocket.writer.writeByte(0x00);
			_controlSocket.writer.writeByte(_controlHandShakeEncryptType);
			final topicCodeUnits = topic.codeUnits;
			final topicLength = topicCodeUnits.length;
			switch (_controlHandShakeEncryptType) {
				case 0x00:
				// no crypt, pass topic and mixKey
					_controlSocket.writer.writeByte(topicLength);
					_controlSocket.writer.writeByteList(topicCodeUnits);
					_controlSocket.writer.writeInt(_controlSocket.slot.mixKey.baseKey);
					break;
				case 0x01:
				// use RSA encrypt
					var rawStr = rsaMagicWord;
					rawStr += String.fromCharCode(topicLength);
					rawStr += topic;
					// add system time obfuscation
					rawStr += DateTime
						.now()
						.millisecondsSinceEpoch
						.toString();
					final encodeStr = await RSAHandShakeEncrypt().encode(_publicKey, rawStr);
					final encodeStrLength = encodeStr.codeUnits.length;
					_controlSocket.writer.writeInt(encodeStrLength);
					_controlSocket.writer.writeString(encodeStr);
					_controlSocket.writer.writeInt(_controlSocket.slot.mixKey.baseKey);
					break;
				default:
					isFinished = true;
					break;
			}
			// Transform byte stream to bridge command stream
			_controlSocket.watchStream(transformBridgeStream<BridgeServerCommand>(
				dataStream: _controlSocket.reader.releaseStream(),
				mixKey: _controlSocket.slot.mixKey
			).listen(handleBridgeCommand, onError: (e, stackTrace) {
				// unknown error, retry
				_reportControlSocketError(
					msg: 'error server reply, error: $e',
					error: e,
					stackTrace: stackTrace,
				);
			}, onDone: () {
				// server reset connection, retry
				_reportControlSocketError(
					msg: 'server disconnected.',
					isWrong: false,
				);
			}, cancelOnError: true));
			
			// wait 10 second, recv server hello
			_controlSocket.wait(10, onTimeOut: () {
				// control socket wait server hello time out
				_reportControlSocketError(
					msg: 'wait server hello message time out.',
				);
			});
			_controlSocket.writer.flush();
		}
		catch (e, stackTrace) {
			if (!isFinished) {
				_reportControlSocketError(
					msg: 'occur error $e',
					error: e,
					stackTrace: stackTrace,
				);
			}
		}
		if (isFinished) {
			if (needLog) {
				logWrong('control socket occur unknow error, stop server');
			}
			_isControlConnected = false;
			destroyServer();
		}
	}
	
	/// Handle control socket command
	void handleBridgeCommand(BridgeServerCommand command) {
		if (command.code == BridgeServerCode.ServerHello) {
			if (!_isControlConnected) {
				// mark connected
				_isControlConnected = true;
				// cancel time out timer
				_controlSocket.cancelWait();
				// start mix key timer
				_beginMixKeyTimer();
				if (needLog) {
					logInfo('control socket connect success...');
				}
			}
			else {
				_reportControlSocketError(
					msg: 'server repeat hello message'
				);
			}
			return;
		}
		
		if (!_isControlConnected) {
			_reportControlSocketError(
				msg: 'server miss hello message'
			);
		}
		
		switch (command.code) {
			case BridgeServerCode.MixKey:
			// do nothing...
				if (needLog) {
					logInfo('server changed mix key');
				}
				break;
			
			case BridgeServerCode.RequestSocketConfirm:
			// find pending request socket
				final socket = _pickPendingVerifySocket(command.message);
				if (socket != null) {
					_addPendingTransportSocket(socket);
					// success
					_controlSocket.writeCommand(BridgeClientCommand(
						code: BridgeClientCode.RequestSocketReplySuccess,
						message: command.message,
					));
				}
				else {
					// failure
					_controlSocket.writeCommand(BridgeClientCommand(
						code: BridgeClientCode.RequestSocketReplyFailure,
						message: command.message,
					));
				}
				break;
				
			case BridgeServerCode.ResponseSocketConfirm:
			// find pending response socket
				final socket = _pickPendingVerifySocket(command.message);
				if (socket != null) {
					_addPendingTransportSocket(socket);
					// success
					_controlSocket.writeCommand(BridgeClientCommand(
						code: BridgeClientCode.ResponseSocketReplySuccess,
						message: command.message,
					));
				}
				else {
					// failure
					_controlSocket.writeCommand(BridgeClientCommand(
						code: BridgeClientCode.ResponseSocketReplyFailure,
						message: command.message,
					));
				}
				break;
				
			case BridgeServerCode.RequestUnknownTopic:
				if (needLog) {
					logWarn('not found corresponding topic.');
				}
				break;
				
			case BridgeServerCode.NeedResponse:
				_connectResponseSocket();
				break;
				
			case BridgeServerCode.TransportRequest:
				final socketBundle = _pickPendingTransportSocket(command.message);
				if (socketBundle == null) {
					// socket not exists
					return;
				}
				_transportSocket(socketBundle);
				if (needLog) {
					logInfo('transporting request socket...');
				}
				break;
				
			case BridgeServerCode.TransportResponse:
				final socketBundle = _pickPendingTransportSocket(command.message);
				if (socketBundle == null) {
					// socket not exists
					return;
				}
				_transportSocket(socketBundle);
				if (needLog) {
					logInfo('transporting response socket...');
				}
				break;
			default:
				// unreachable
				break;
		}
	}
	
	/// Start Timer to change mix key
	void _beginMixKeyTimer() {
		_mixKeyTimer = Timer.periodic(const Duration(seconds: 60), (timer) {
			// change mix key
			final newKey = Random().nextInt(0xFFFFFFFF);
			_controlSocket.writeCommand(BridgeClientCommand(
				code: BridgeClientCode.MixKey,
				message: newKey
			));
			_controlSocket.slot.mixKey = MixKey(newKey);
		});
	}
	
	/// Retry to connect bridge server again after 10 seconds
	void _retryConnectControlSocket() {
		Future.delayed(const Duration(seconds: 10)).then((_) {
			_connectControlSocket();
		});
	}
	
	/// Generate socket key
	String _genSocketKey() {
		final keyStr = _keyCode.toRadixString(16);
		_keyCode ++;
		if (_keyCode == 0xFFFFFFFF) {
			_keyCode = 0;
		}
		return keyStr;
	}
	
	
	/// Transport request socket and response socket
	void _transportSocket(BridgeSocketBundle socketBundle) {
		socketBundle.slot.onDestroy = (bundle) {
			if(needLog) {
				if(bundle.slot.isRequest) {
					logInfo('request transport completed. ');
				}
				else {
					logInfo('response transport completed. ');
				}
			}
		};
		// create transport
		final requestTransport = StreamTransport(
			socketBundle.reader.releaseStream(),
			bindData: socketBundle,
			streamDone: (srcTransport, otherTransport) {
				srcTransport.slot.destroy();
				otherTransport?.destroy();
			},
			recvStreamData: (srcTransport, List<int> data) {
				socketBundle.socket.add(data);
				return;
			},
			streamError: (transport, e, [stackTrace]) {}
		);
		
		// create response transport
		final responseTransport = StreamTransport(
			socketBundle.slot.proxySocket,
			bindData: socketBundle,
			streamDone: (transport, otherTransport) {
				transport.slot.destroy();
				otherTransport?.destroy();
			},
			recvStreamData: (transport, List<int> data) {
				socketBundle.slot.proxySocket.add(data);
				return;
			},
			streamError: (transport, e, [stackTrace]) {}
		);
		
		
		requestTransport.transportToTransport(responseTransport);
		responseTransport.transportToTransport(requestTransport);
	}
	
	/// Control socket occur error, clean socket resources and try to re-connect
	void _reportControlSocketError({String msg, bool isWrong = true, dynamic error, StackTrace stackTrace}) {
		if (needLog) {
			if (isWrong ?? true) {
				logWrong('$msg, will retry after 10 second...');
			}
			else {
				logWarn('$msg, will retry after 10 second...');
			}
			if (error != null) {
				logError(error, stackTrace);
			}
		}
		_isControlConnected = false;
		_controlSocket?.destroy();
		_controlSocket = null;
		_mixKeyTimer?.cancel();
		_mixKeyTimer = null;
		_retryConnectControlSocket();
	}
	
	
	/// Destroy control socket
	void _destroyControlSocket() {
		_isControlConnected = false;
		_controlSocket?.destroy();
		if (needLog) {
			logInfo('close control socket');
		}
	}
}