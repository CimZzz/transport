
/// Created by CimZzz
/// Transport 桥接服务器
/// 用来处理多种 Socket 类型，实现代理的目的，是桥接代理的核心服务
/// 
/// QuerySocket: 查询 Socket 类型，仅用来查询指定桥接服务器的信息
/// 
/// RequestSocket: 代理请求端 Socket 类型，作为代理的发起端
/// 
/// ResponseSocket: 代理响应端 Socket 类型，作为代理的响应端
/// 
/// RequestSocket -> Bridge -> ResponseSocket -> 处理请求内容

import 'dart:io';
import 'dart:convert';

import 'package:stream_data_reader/stream_data_reader.dart';
import 'package:transport/src/proxy_completer.dart';
import 'package:transport/src/transport/new/serialize.dart';

import '../../step.dart';
import 'socket_wrapper.dart';


/// 查询 Socket 类型
const kSocketTypeQuery = 0;

/// 请求 Socket 类型
const kSocketTypeRequest = 1;

/// 响应 Socket 类型
const kSocketTypeResponse = 2;

/// 会话 Socket 类型
/// 来自请求 Socket，表示需要响应 Socket 回复代理链接
const kSocketTypeSession = 3;

/// 回复 Socket 类型
/// 来自响应 Socket，与会话 Socket 做匹配
const kSocketTypeReply = 4;

/// 查询指令 - 查询全部响应客户端
const kQueryCommand_Client = 0;

/// 代理模式 - 普通代理模式
const kProxyMode_Normal = 0;


/// Transport Bridge 配置信息
class TransportBridgeOptions {
  TransportBridgeOptions({this.port, this.ip = '0.0.0.0'});

  /// Transport Bridge 监听端口
  final int port;

  /// Transport Bridge 监听 IP 地址
  final String ip;
}

/// Transport Bridge Client
class TransportClient extends SocketWrapper {
  TransportClient(Socket socket) : super(socket);

  /// Socket 类型
  var socketType = kSocketTypeQuery;

  /// Socket 对应 Client Id
  String clientId;

  /// Socket 特殊用途 Completer
  ProxyCompleter _completer;
}

/// 代理匹配域
class ProxyMatchScope {
  ProxyMatchScope(this.matchCode);

  /// 匹配码
  final int matchCode;
  /// 会话客户端
  TransportClient sessionClient;
  /// 代理客户端
  TransportClient replyClient;

  /// 匹配计时开始
  Future countdown() {
    final step = TimeoutStep(timeout: const Duration(seconds: 10));
    step.doAction().then((_) {
      step.innerCompleter.complete(null);
    }, onError: (error, [stackTrace]) {
      step.innerCompleter.completeError(error, stackTrace);
    });

    return step.innerCompleter.future;
  }

  void tryMatch() {

  }
}

/// Transport Bridge - 桥接服务器
class TransportBridge {
  TransportBridge._(this.options);

  /// 监听端口，启动桥接服务器
  static Future<TransportBridge> listen(TransportBridgeOptions options) async {
    final bridge = TransportBridge._(options);
		final socket = await ServerSocket.bind(options.ip, options.port);

		socket.listen(bridge._processSocketAccept,
     onError: (error, [stackTrace]) {
			/// todo 处理错误异常回调
		});
    
    return bridge;
  }


  /// =================================================
  /// 内部成员属性
  /// =================================================


  /// 桥接服务器配置选项
  final TransportBridgeOptions options;

  /// 判断桥接服务器是否已经关闭
  var _isClosed = false;

  /// 响应 Client 表
  /// key = client id
  final Map<String, TransportClient> _responseClientMap = {};

  /// 匹配域列表
  final Map<int, ProxyMatchScope> _matchScopeMap = {};


  /// 请求 & 响应匹配码
  /// 用来将请求 Socket 和 响应 Socket 做匹配
  var matchCode = 0;

  /// =================================================
  /// 对外暴露方法
  /// =================================================
  
	/// 关闭桥接服务器
	void close(dynamic error, [stackTrace]) {
		if(!_isClosed) {
			_isClosed = true;
			/// todo 关闭逻辑
			/// 1. 关闭 Server Socket
			/// 2. 触发回调
		}
	}


  /// =================================================
  /// 内部处理方法
  /// =================================================

	/// 处理已经到来的 Socket
	void _processSocketAccept(Socket socket) {
    /// Socket Wrapper
    final client = TransportClient(socket);
    final timeoutStep = TimeoutStep<TransportClient>(timeout: Duration(seconds: 10));
    timeoutStep.doAction().then((TransportClient client) {
      /// 握手成功
      _handshakeSuccess(client);
    }, onError: (e, [stackTrace]) {
      /// 握手失败
      /// todo 处理握手失败
    });
    timeoutStep.innerCompleter.complete(_socketHandshake(client));
	}

  /// Socket 握手
  Future<TransportClient> _socketHandshake(TransportClient client) async {
		final socket = client.socket;
		final reader = client.reader;

		// 第一步，接收验证的魔术字
		final magicWordBytes = await reader.readBytes(length: 9);
		final magicWord = String.fromCharCodes(magicWordBytes);
		if(magicWord != 'Transport') {
			// 验证失败
      throw Exception('魔术字验证失败');
		}

		// 第二步，接收 Socket 类型
		// 0 - 控制 Socket - 无需 ClientId
		// 1 - Request Socket - 需要 ClientId
		// 2 - Response Socket - 需要 ClientId
		final socketType = await reader.readOneByte() & 0xFF;
		if(socketType < 0 || socketType > 2) {
			// 类型错误
      throw Exception('非法 Socket 类型');
		}

    switch(socketType) {
      case kSocketTypeQuery:
        // 无动作
        break;
      case kSocketTypeRequest:
        // 解析想要访问的 Client Id
        final clientIdLength = await reader.readOneByte() & 0xFF;
        final clientIdBytes = await reader.readBytes(length: clientIdLength);
        final clientId = utf8.decode(clientIdBytes);
        client.clientId = clientId;
        break;
      case kSocketTypeResponse:
        // 解析想要申请的 Client Id
        final clientIdLength = await reader.readOneByte() & 0xFF;
        final clientIdBytes = await reader.readBytes(length: clientIdLength);
        final clientId = utf8.decode(clientIdBytes);
        client.clientId = clientId;
        break;
    }

    /// 最后一步，握手成功，发送魔术字
		final magicBytes = 'Transport'.codeUnits;
		socket.add(magicBytes);
		await socket.flush();

    return client;
  }

  /// 处理握手成功流程
  /// 根据不同的 Socket 类型区分处理
  void _handshakeSuccess(TransportClient client) {
    switch(client.socketType) {
      case kSocketTypeQuery:
      // 查询 Socket 类型
        _querySocketHandle(client);
        break;
      case kSocketTypeRequest:
      // 请求 Socket 类型
        _requestSocketHandle(client);
        break;
      case kSocketTypeResponse:
      // 响应 Socket 类型
        _responseSocketHandle(client);
        break;
    }
  }

  /// 处理查询 Socket
  void _querySocketHandle(TransportClient client) {
    final timeoutStep = TimeoutStep(timeout: Duration(seconds: 10));
    timeoutStep.doAction().then((result) {
      /// 完成指令后，关闭
      /// todo
    }, onError: (e, [stackTrace]) {
      /// 异常处理
      /// todo
    });

    timeoutStep.innerCompleter.complete(() async {
      // 处理查询 Socket 指令
      final socket = client.socket;
      final reader = client.reader;
      final cmdType = await reader.readOneByte();
      switch(cmdType) {
        case kQueryCommand_Client:
        // 查询目前全部的响应客户端
          final clientInfoList = <TransportClientInfo>[];
          _responseClientMap.forEach((clientId, client) {
            clientInfoList.add(TransportClientInfo(
              clientId: clientId
            ));
          });
          final totalLength = clientInfoList.length;
          socket.add([totalLength & 0xFF, (totalLength >> 8) & 0xFF]);
          socket.add(await serializeTransportClient(clientInfoList));
          await socket.flush();
          break;
      }
      return true;
    }());
  }

  /// 处理请求 Socket
  void _requestSocketHandle(TransportClient client) async {
    transformByteStream(client.reader.releaseStream(), (reader) async {
      try {
        final reqType = await reader.readOneByte();
        switch(reqType) {
          case 0x00:
          // 收到心跳报文
           
          break;
          case 0x01:
          // 收到请求代理指令
          
          final responseClient = _responseClientMap[client.clientId];
          if(responseClient != null) {
            // 存在对应的响应 Socket, 建立匹配域
          }
          break;
        }
      }
      catch(e, stackTrace) {
        /// 请求 Socket 发生异常
        /// todo
      }
    });
    // final reader = client.reader;
    // try {
    //     // 解析请求 Socket 想要代理的信息
    //     // - Client: 想要代理的 ClientId
    //     // - ProxyMode: 代理模式
    //     //    - 0: 常规代理模式
    //     //    - 1: 指令代理模式（未实现）
    //     //    - 2: 文件模式（未实现）
    //     //
    //     //
    //     // ----- 常规代理模式
    //     // - Ip: 想要通过代理访问的 Ip 地址
    //     // - Port: 想要通过代理访问的端口号
    //     final clientIdLength = await reader.readOneByte() & 0xFF;
    //     final clientIdBytes = await reader.readBytes(length: clientIdLength);
    //     final clientId = utf8.decode(clientIdBytes);

    //     final proxyMode = await reader.readOneByte() & 0xFF;
    //     switch(proxyMode) {
    //       case kProxyMode_Normal:
    //       // 普通代理模式
    //         break;
    //     }
    // }
    // catch(e, [stackTrace]) {

    // }
  }

  /// 处理响应 Socket
  void _responseSocketHandle(TransportClient client) {
    // 查看 ClientId 是否重复
    if(_responseClientMap.containsKey(client.clientId)) {
      // ClientId 重复，关闭 Client
      client.close();
      return;
    }

    // 注册 Client
    _responseClientMap[client.clientId] = client;
    client.reader.releaseStream().listen((event) {
      /// 监听事件
      /// todo 目前仅做心跳监听
    }, onError: (e, [stackTrace]) {
      /// Response Socket 异常关闭
      _responseClientMap.remove(client.clientId);
      client.close();
    });
  }
}