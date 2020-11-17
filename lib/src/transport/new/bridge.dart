
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
import 'package:transport/src/transport/new/connection.dart';

import '../../int_generator.dart';
import '../../step.dart';
import 'command_writer.dart';
import 'heartbeat_machine.dart';
import 'serialize.dart';
import 'socket_wrapper.dart';

/// 查询 Socket 类型
const kSocketTypeQuery = 0;

/// 请求 Socket 类型
const kSocketTypeRequest = 1;

/// 响应 Socket 类型
const kSocketTypeResponse = 2;

/// 回复 Socket 类型
/// 来自响应 Socket，与会话 Socket 做匹配
const kSocketTypeReply = 3;

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

  /// 匹配码
  int matchCode;

  /// 心跳机
  HeartbeatMachine _heartbeatMachine;

  /// 目前匹配码集合
  Map<int, ProxyMatchScope> _matchCodeMap;
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
  /// 超时步骤
  TimeoutStep _step;

  /// 匹配计时开始
  Future countdown() {
    final step = TimeoutStep(timeout: const Duration(seconds: 10));
    _step = step;
    return step.doAction();
  }

  /// 尝试匹配
  void tryMatch() {
    if(sessionClient == null || replyClient == null) {
      return;
    }

    // 匹配成功
    _step.innerCompleter.complete();
  }
}

/// Transport Bridge - 桥接服务器
class TransportBridge {
  TransportBridge._(this.options);

  /// 监听端口，启动桥接服务器
  static Future<TransportBridge> listen(TransportBridgeOptions options) async {
    final bridge = TransportBridge._(options);
		final socket = await ServerSocket.bind(options.ip, options.port);
    bridge._serverSocket = socket;
		socket.listen(bridge._processSocketAccept,
     onError: (error, [stackTrace]) {
			bridge.close(error, stackTrace);
		});
    
    return bridge;
  }


  /// =================================================
  /// 内部成员属性
  /// =================================================


  /// 桥接服务器配置选项
  final TransportBridgeOptions options;

  /// ServerSocket 对象
  ServerSocket _serverSocket;

  /// 判断桥接服务器是否已经关闭
  var _isClosed = false;

  /// 响应 Client 表
  /// key = client id
  final Map<String, TransportClient> _responseClientMap = {};

  /// 请求 & 响应匹配码
  /// 用来将请求 Socket 和 响应 Socket 做匹配
  final IntGenerator matchCodeGenerator = IntGenerator();

  /// =================================================
  /// 对外暴露方法
  /// =================================================
  
	/// 关闭桥接服务器
	void close(dynamic error, [stackTrace]) {
		if(!_isClosed) {
			_isClosed = true;
      _serverSocket?.close();
      _serverSocket = null;
      _responseClientMap.values.forEach((client) {
        _closeClient(client);
      });
		}
	}


  /// =================================================
  /// 内部处理方法
  /// =================================================
  
  /// 关闭指定 Client
  /// ### 完成
  void _closeClient(TransportClient client) {
    client._heartbeatMachine?.cancel();
    client.close();
    if(client.socketType == kSocketTypeResponse && client.clientId != null) {
      // 关闭 Response Socket
      _responseClientMap.remove(client.clientId);
      // 同时关闭目前所有正在代理的 Socket
      if(client._matchCodeMap != null) {
        client._matchCodeMap.forEach((matchCode, proxyScope) {
          _closeClient(proxyScope.sessionClient);
          _closeClient(proxyScope.replyClient);
        });
        client._matchCodeMap = null;
      }
    }
    if(((client.socketType == kSocketTypeReply) || (client.socketType == kSocketTypeRequest)) && client.matchCode != null) {
      // 关闭 Request Socket & Reply Socket 的 ProxyMatchScope
      final responseClient = _responseClientMap[client.clientId];
      if(responseClient != null) {
        final proxyMatchScope = responseClient._matchCodeMap.remove(client.matchCode);
        if(proxyMatchScope != null) {
          proxyMatchScope?.sessionClient?.close();
          proxyMatchScope?.replyClient?.close();
        }
      }
    }
  }

  /// 启动 Client 心跳机
  /// ### 完成
  void _startClientHeartbeat(TransportClient client) {
    client._heartbeatMachine = HeartbeatMachine(
      interval: const Duration(seconds: 1),
      remindCount: 6,
      timeoutCount: 10,
    );
    // 启动心跳机
    client._heartbeatMachine.monitor().listen((_) {
      // 推送心跳报文
      CommandWriter.sendHeartbeat(client.socket, isNeedReply: true);
    }, onError: (error) {
      // 心跳超时
      _closeClient(client);
    });
  }

	/// 处理已经到来的 Socket
  /// ### 完成
	void _processSocketAccept(Socket socket) {
    /// Socket Wrapper
    final client = TransportClient(socket);
    final timeoutStep = TimeoutStep<TransportClient>(timeout: Duration(seconds: 10));
    timeoutStep.doAction().then((TransportClient client) {
      /// 握手成功
      _handshakeSuccess(client);
    }, onError: (e, [stackTrace]) {
      /// 握手失败
      client.close();
    });
    timeoutStep.innerCompleter.complete(_socketHandshake(client));
	}

  /// Socket 握手
  /// ### 完成
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
      case kSocketTypeReply:
        // 解析想要代表的 Client Id
        final clientIdLength = await reader.readOneByte() & 0xFF;
        final clientIdBytes = await reader.readBytes(length: clientIdLength);
        final clientId = utf8.decode(clientIdBytes);
        client.clientId = clientId;

        // 解析匹配的 Match Code
        final matchCode = await reader.readInt(bigEndian: false);
        client.matchCode = matchCode;
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
  /// #### 完成
  void _handshakeSuccess(TransportClient client) {
    if(client.socketType == kSocketTypeQuery) {
      // 查询 Socket 类型
      _querySocketHandle(client);
      return;
    }

    switch(client.socketType) {
      case kSocketTypeRequest:
      // 请求 Socket 类型
        _requestSocketHandle(client);
        break;
      case kSocketTypeResponse:
      // 响应 Socket 类型
        _responseSocketHandle(client);
        break;
      case kSocketTypeReply:
      // 回复 Socket 类型
        _replySocketHandle(client);
        break;
    }
  }

  /// 处理查询 Socket
  /// 未完成
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
  /// ### 完成
  void _requestSocketHandle(TransportClient client) {
    // 查找指定 ClientId 的 Response Socket
    final responseClient = _responseClientMap[client.clientId];
    if(responseClient == null) {
      // 没有找到对应 Response Socket
      client.close();
      return;
    }

    // 生成匹配码，创建匹配域
    final matchCode = matchCodeGenerator.nextCode();
    if(responseClient._matchCodeMap.containsKey(matchCode)) {
      // 已经存在对应的匹配码，表示当前服务器超载，关闭 Client
      client.close();
      return;
    }

    final matchScope = ProxyMatchScope(matchCode);
    client.matchCode = matchCode;
    responseClient._matchCodeMap[matchCode] = matchScope;
    matchScope.sessionClient = client;
    matchScope.countdown().then((_) {
      // 匹配成功
      SocketConnection(matchScope.sessionClient).doTransport(SocketConnection(matchScope.replyClient)).then((_) {
        // 传输完成
        _closeClient(client);
      }, onError: (error) {
        // 传输过程中发生异常，终止传输
        _closeClient(client);
      });
    }, onError: (error) {
      // 等待匹配超时
      _closeClient(client);
    });
    responseClient._matchCodeMap[matchCode] = matchScope;

    // 向 ResponseClient 发送指令
    CommandWriter.sendApplyReply(responseClient.socket, matchCode).catchError((error) {
      // 发送响应指令失败，立即终止 Response Socket
      _closeClient(responseClient);
    });
  }

  /// 处理响应 Socket
  /// ### 完成
  void _responseSocketHandle(TransportClient client) {
    // 查看 ClientId 是否重复
    if(_responseClientMap.containsKey(client.clientId)) {
      // ClientId 重复，关闭 Client
      client.close();
      return;
    }

    client._matchCodeMap = {};
    // 注册 Client
    _responseClientMap[client.clientId] = client;
    // 开启心跳监控
    _startClientHeartbeat(client);
    transformByteStream(client.reader.releaseStream(), (dataReader) async {
      try {
        client._heartbeatMachine?.clearCount();
        final cmdType = await dataReader.readOneByte() & 0xFF;
        switch(cmdType) {
          case 0x00:
          // 收到心跳报文
            final isNeedReply = await dataReader.readOneByte() & 0xFF;
            if(isNeedReply == 0x01) {
              await CommandWriter.sendHeartbeat(client.socket);
            }
            break;
        }
      }
      catch(error) {
        // 连接过程中发生异常，关闭 Response Socket
        _closeClient(client);
      }
    });
  }

  /// 处理回复 Socekt
  /// ### 完成
  void _replySocketHandle(TransportClient client) {
    final responseClient = _responseClientMap[client.clientId];
    if(responseClient == null) {
      // 已经不存在对应的 Response Socket了，关闭 Reply Socket
      client.close();
      return;
    }

    final proxyMatchScope = responseClient._matchCodeMap[client.matchCode];
    if(proxyMatchScope == null) {
      // 已经不存在对应的匹配域了，关闭 Reply Socket
      client.close();
      return;
    }

    proxyMatchScope.replyClient = client;
    proxyMatchScope.tryMatch();
  }
}