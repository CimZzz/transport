import 'dart:async';
/// Created by CimZzz
/// Response 代理连接
/// 抽象出来作为代理连接的基类

import 'dart:io';

import 'package:transport/src/transport/new/socket_wrapper.dart';

import '../../proxy_completer.dart';

/// 连接基类
abstract class Connection {
  /// 开启数据流
  Stream<List<int>> openStream();

  /// 写入数据
  Future<void> writeData(List<int> data);

  /// 关闭流连接
  void close();

  /// 连接完成 Completer
  ProxyCompleter _completer;

  /// 判断是否处于传输过程中
  var _isTransporting = false;

  /// 进行数据传输
  Future<void> doTransport(Connection connection) {
    _isTransporting = true;
    connection.openStream().listen((event) async {
      try {
        await writeData(event);
      }
      catch(e) {
        close();
        if(_isTransporting) {
          _isTransporting = false;
          connection.close();
        }
        _completer.complete(null);
      }
    }, onError: (e, [stackTrace]) {
      close();
      if(_isTransporting) {
        _isTransporting = false;
        connection.close();
      }
      _completer.complete(null);
    });
    openStream().listen((event) async {
      try  {
        await connection.writeData(event);
      } catch(e) {
        close();
        if(_isTransporting) {
          _isTransporting = false;
          connection.close();
        }
      _completer.complete(null);
      }
    }, onError: (e, [stackTrace]) {
      close();
      if(_isTransporting) {
        _isTransporting = false;
        connection.close();
      }
      _completer.complete(null);
    });
    return _completer.future;
  }
}

/// Socket 连接基类
class SocketConnection extends Connection {
  SocketConnection(this._socketWrapper);
  SocketWrapper _socketWrapper;


  @override
  void close() {
    _socketWrapper?.close();
    _socketWrapper = null;
  }

  @override
  Stream<List<int>> openStream() => _socketWrapper.reader.releaseStream();

  @override
  Future<void> writeData(List<int> data) {
    _socketWrapper?.socket?.add(data);
    return _socketWrapper?.socket?.flush();
  }
}

/// 代理 Connect
/// 离散化连接
class ProxyConnection extends Connection {
  ProxyConnection(this.writeDataCallback);

  final Future<void> Function(List<int> data) writeDataCallback;
  var _controller = StreamController<List<int>>();

  @override
  void close() {
    _controller?.close();
    _controller = null;
  }

  @override
  Stream<List<int>> openStream() => _controller?.stream;

  @override
  Future<void> writeData(List<int> data) {
    return writeDataCallback(data);
  }

  /// 向流中追加数据
  void addStreamData(List<int> data) {
    _controller?.add(data);
  }
}

/// 本地代理连接
class LocalResponseConnection extends Connection {
  LocalResponseConnection({this.ipAddress, this.port});
  
  final String ipAddress;
  final int port;
  Socket _socket;

  @override
  void close() {
    _socket?.destroy();
    _socket = null;
  }

  @override
  Stream<List<int>> openStream() async* {
    _socket ??= await Socket.connect(ipAddress, port);
    yield* _socket;
  }

  @override
  Future<void> writeData(List<int> data) async {
    _socket?.add(data);
    await _socket?.flush();
  }
}