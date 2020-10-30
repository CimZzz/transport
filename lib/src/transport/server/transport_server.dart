
import 'dart:convert';
import 'dart:io';

import 'package:stream_data_reader/stream_data_reader.dart';

import 'command_controller.dart';
import 's2c_step.dart';
import 'serialize.dart';
import 'socket_bundle.dart';
import 'transport_client.dart';


/// When server close, call this callback.
/// * Only call it at first time.
///
/// If closed reason is error, call it with error information
typedef ServerCloseCallback = void Function(dynamic error, [StackTrace stackTrace]);

/// Server data bundle factory
/// You can use this to customize data bundle any you want
typedef ServerDataBundleFactory = TransportServerDataBundle Function();

/// Transport Client
class TransportClient {
    TransportClient(this.socketBundle);

  /// Socket Bundle
	final SocketBundle socketBundle;

  /// Transport Server Command Controller
  TransportServerCommandController commandController;

  /// Heartbeat wait time
  /// if wait time over 60 seconds, server will disconnect this client
  /// 
  /// Any command will refresh wait time, not only heartbeat command 
  var waitHeartbeatTime = 0;
}

/// Transport server data bundle
/// Override it and expand field if you need
class TransportServerDataBundle {
	/// Exist client map
	final Map<String, TransportClient> _clientMap = {};
  int get clientCount => _clientMap.length;

	/// Register Control Socket as `Client`
	bool _registerControlClient(SocketBundle socketBundle, String clientId) {
		if(_clientMap.containsKey(clientId)) {
			return false;
		}

		_clientMap[clientId] = TransportClient(socketBundle);
		return true;
	}

	/// Check Control Socket is exists
	bool _checkClient(String clientId) {
		return _clientMap.containsKey(clientId);
	}

  /// Rewrite `[]` operator, return TransportClient by clientId
  TransportClient operator [] (String clientId) {
    return _clientMap[clientId];
  }

  /// For each
  void forEach(void Function(String clientId, TransportClient client) forEach) {
    _clientMap.forEach(forEach);
  }

  /// Map
  List<R> map<R>(R Function(String clientId, TransportClient client) forEach) {
    final list = <R>[];
    _clientMap.forEach((key, value) {
      list.add(forEach(key, value));
    });
    return list;
  }
}

/// Transport server
/// listen port and process transport connection
/// need specify server ip and port
class TransportServer {
    TransportServer(this.ip, this.port, {
      ServerCloseCallback closeCallback,
      ServerDataBundleFactory dataBundleFactory,
    }):
		    assert(ip != null),
		    assert(port != null),
		    _serverCloseCallback = closeCallback,
        _serverDataBundle = (dataBundleFactory == null ? TransportServerDataBundle() : dataBundleFactory()) ?? TransportServerDataBundle();

    /// Server ip address
	final String ip;

	/// Server port
	final int port;

	/// Server close
	final ServerCloseCallback _serverCloseCallback;

	/// Whether server is closed
	var _isClosed = false;

	/// Server socket
	ServerSocket _serverSocket;

  /// Server data bundle
  TransportServerDataBundle _serverDataBundle;

	/// Do listen.
  /// When listen success, return true, either return false or throw exception
	Future<bool> listen() async {
		final socket = await ServerSocket.bind(ip, port);
		if(_isClosed) {
			await socket.close();
		}
		socket.listen((socket) {
			_processSocketAccept(socket);
		}, onError: (error, [stackTrace]) {
			/// todo 处理错误异常回调
		});
		return true;
	}

	/// Close transport server
	void close(dynamic error, [stackTrace]) {
		if(!_isClosed) {
			_isClosed = true;
			/// todo 关闭逻辑
			/// 1. 关闭 Server Socket
			/// 2. 触发回调
		}
	}

	/// Process incoming socket.
    /// Socket has 3 type:
    ///
    /// Type One:
    ///
    /// Control Socket, which communicate with transport server reality, send
    /// some control command to implement transaction.
    ///
    /// Type Two:
    ///
    /// Request Socket, request peer socket. When server receive it, will call peer control socket to construct specify connection
    /// to response to request socket
    ///
    /// Type Three:
    ///
    /// Response Socket
    ///
	void _processSocketAccept(Socket socket) {
		final socketBundle = SocketBundle (
			socket: socket,
			reader: ByteBufferReader(StreamReader(socket)),
			// todo 加密方法
			encryptFunc: null,
			// todo 解密方法
			decryptFunc: null,
			// 加密参数方法（Server 端用不到）
			encryptParamsFunction: null,
			// todo 解析加密参数方法
			analyzeEncryptParamsFunction: null,
		);

		HandShakeRespStep (
			socketBundle,
			registerClientCallback: _serverDataBundle._registerControlClient,
			checkClientCallback: _serverDataBundle._checkClient,
			constructRequestCallback: _receiveRequestSocket,
			constructResponseCallback: _receiveResponseSocket
		).doAction().then((isSuccess) {
			if(!_isClosed && isSuccess) {
				// 创建成功
				_handshakeSuccess(socketBundle);
			}
			else {
				// 握手失败
				socketBundle.close();
			}
		}, onError: (e, [stackTrace]) {
			// todo 分析握手失败原因
			socketBundle.close();
		});
	}



	/// Receive request socket
	bool _receiveRequestSocket(SocketBundle socketBundle, int flagCode) {
    if(!_serverDataBundle._checkClient(socketBundle.clientId)) {
			return false;
    }
		// todo 处理后续请求 Socket 逻辑
		return true;
	}

	/// Receive response socket
	bool _receiveResponseSocket(SocketBundle socketBundle, int flagCode) {
    if(!_serverDataBundle._checkClient(socketBundle.clientId)) {
			return false;
    }
		// todo 处理后续请求 Socket 逻辑
		return true;
	}

	/// When handshake success, call this function
	void _handshakeSuccess(SocketBundle socketBundle) {
		if(socketBundle.socketType != kSocketTypeControl) {
			return;
		}

    final client = _serverDataBundle[socketBundle.clientId];
    client.commandController = TransportServerCommandController(_serverDataBundle, client);

    client.commandController.beginCommandLoop().catchError((e) {
				// 接收数据失败，连接终端
				// todo 处理连接中断逻辑
    });
	}
}


/// Command Type - Request Transfer
const Bridge_Command_Type_Request_Transfer = 0x02;

/// Transport Server Command Controller
class TransportServerCommandController extends CommandController {
  TransportServerCommandController(this.dataBundle, this.client) : super(client.socketBundle);

  /// Transport Server Data Bundle
  final TransportServerDataBundle dataBundle;

  /// Transport Client
  final TransportClient client;

	/// When control socket ask for another control socket, via server
	/// send request transfer.
	///
	/// The peer client will support response socket in five seconds
	///
	///   0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7
	/// + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
	/// |      type      |     cmdIdx    |             port               |
	/// - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	/// |                            ipAddress                            |
	/// + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
	///
	/// type: int, 8 bits (1 bytes) , always 0x02
	/// cmdIdx: int, 8 bits (1 bytes) , command idx, use to match command req & res
	/// port: int, 16 bits (2 bytes) , peer client want to access specify port
	/// ipAddress: int, 32 bits (4 bytes) , via peer client, access specify ip address. always 0x7F00000000(127.0.0.1)
  /// 
  /// Client Reply:
  ///
  ///   0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7 0 1 2 3 4 5 6 7  
  /// + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
  /// |      type      |   replyIdx    |    cmdType    |    success     |
  /// + - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - +
  /// 
  /// type: int, 8 bits (1 bytes) , always 0x01
  /// replyIdx: int, 8 bits (1 bytes) , reply idx, use to match command req & res, 0 represent no-res req
  /// cmdType: int, 8 bits (1 bytes) , source command type, always 0x02
  /// success: int, 8 bits (1 bytes) , request result, if success is 0, else is 1 
  /// 
	///
	Future<bool> sendRequestTransfer(int ipAddress, int port) async {
		final bytesList = <int>[];
		bytesList.add(port & 0xFF);
		bytesList.add((port >> 8) & 0xFF);
		bytesList.add(ipAddress & 0xFF);
		bytesList.add((ipAddress >> 8) & 0xFF);
		bytesList.add((ipAddress >> 16) & 0xFF);
		bytesList.add((ipAddress >> 24) & 0xFF);

    final cmdIdx = nextCmdIdx();
		await sendCommand(Bridge_Command_Type_Request_Transfer, cmdIdx: cmdIdx, byteBuffer: bytesList);
    return waitCommand(cmdIdx);
	}

  /// Handle client command
  @override
  Future<bool> handleCommand(int commandType, int idx, DataReader reader) async {
    // Any message can reset wait heartbeat time
    client.waitHeartbeatTime = 0;
    switch(commandType) {
      case Command_Type_Heartbeat:
        // Receive Heartbeat
        // Nothing
        return true;

      case Command_Type_Reply: {
        // Receive client reply
        final srcCommandType = await reader.readOneByte() & 0xFF;
        var handleResult = false;
        switch(srcCommandType) {
          case Bridge_Command_Type_Request_Transfer:
            // Send request transfer command result
            final isSuccess = await reader.readOneByte() & 0xFF;
            completeCommand(idx, isSuccess);
            handleResult = true;
            break;
          default:
            handleResult = await handleAnotherReply(commandType, idx, srcCommandType, reader);
            break;
        }
        return handleResult;
      }

      case Client_Command_Type_Query_Client: {
        // Receive client query command
        var clientCount = dataBundle.clientCount;
        try {
          final bufferList = await serializeTransportClient(dataBundle.map((clientId, client) 
              => TransportClientOptions(clientId: client.socketBundle.clientId)));
          bufferList.insert(0, clientCount & 0xFF);
          await sendReply(Client_Command_Type_Query_Client, idx, byteBuffer: bufferList);
        }
        catch(e) {
          final bufferList = [0x00];
          await sendReply(Client_Command_Type_Query_Client, idx, byteBuffer: bufferList);
        }
        return true;
      }

      case Client_Command_Type_Request: {
        // Receive client request peer client command
        final port = await reader.readShort(bigEndian: false);
        final ipAddress = await reader.readInt(bigEndian: false);
        final transportType = await reader.readOneByte() & 0xFF;

        if(transportType != 0x00) {
          return false;
        }

        final length = await reader.readOneByte() & 0xFF;
        final clientId = utf8.decode(await reader.readBytes(length: length));
        
        final client = dataBundle[clientId];
        if(client == null) {
          await sendReply(commandType, idx, byteBuffer: [0x01]);
          return true;
        }

        await sendRequestTransfer(ipAddress, port);
        return true;
      }
      
      default:
        return await handleAnotherCommand(commandType, idx, reader);
    }
  }

  /// Handle another command
  /// If you want to custom command, you may be can use override it to implement.
  Future<bool> handleAnotherCommand(int commandType, int idx, DataReader reader) async {
    return false;
  }

  /// Handle another command reply
  /// If you want to custom command, you may be can use override it to implement.
  Future<bool> handleAnotherReply(int commandType, int idx, int srcCommandType, DataReader reader) async {
    return false;
  }
}