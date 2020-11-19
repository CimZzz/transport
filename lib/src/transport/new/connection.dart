import 'dart:async';

/// Created by CimZzz
/// Response 代理连接
/// 抽象出来作为代理连接的基类

import 'dart:io';

import '../../proxy_completer.dart';
import 'socket_wrapper.dart';

/// 连接基类
abstract class Connection {
  /// 开启数据流
  Stream<List<int>> openStream();

  /// 写入数据
  void writeData(List<int> data);

  /// 保证请求正常连接
  Future<void> checkConnection();

  /// 关闭流连接
  void close();

  /// 连接完成 Completer
  ProxyCompleter _completer;

  /// 判断是否处于传输过程中
  var _isTransporting = false;

  /// 进行数据传输
  Future<void> doTransport(Connection connection) async {
    _completer = ProxyCompleter();
    _isTransporting = true;
    try {
      await checkConnection();
      await connection.checkConnection();

      connection.openStream().listen((event) {
        try {
          writeData(event);
        } catch (error, stackTrace) {
          close();
          if (_isTransporting) {
            _isTransporting = false;
            connection.close();
          }
          _completer.completeError(error, stackTrace);
        }
      }, onError: (error, stackTrace) {
        close();
        if (_isTransporting) {
          _isTransporting = false;
          connection.close();
        }
        _completer.completeError(error, stackTrace);
      }, onDone: () {
        // 完成
        close();
        if (_isTransporting) {
          _isTransporting = false;
          connection.close();
        }
        _completer.complete(null);
      });

      openStream().listen((event) {
        try {
          connection.writeData(event);
        } catch (error, stackTrace) {
          close();
          if (_isTransporting) {
            _isTransporting = false;
            connection.close();
          }
          _completer.completeError(error, stackTrace);
        }
      }, onError: (error, stackTrace) {
        close();
        if (_isTransporting) {
          _isTransporting = false;
          connection.close();
        }
        _completer.completeError(error, stackTrace);
      }, onDone: () {
        // 完成
        close();
        if (_isTransporting) {
          _isTransporting = false;
          connection.close();
        }
        _completer.complete(null);
      });
    } catch (error, stackTrace) {
      _completer.completeError(error, stackTrace);
    }

    return await _completer.future;
  }
}

/// Socket 连接基类
class SocketConnection extends Connection {
  SocketConnection(this._socketWrapper);
  SocketWrapper _socketWrapper;

  @override
  Future<void> checkConnection() {
    return Future.value();
  }

  @override
  void close() {
    _socketWrapper?.close();
    _socketWrapper = null;
  }

  @override
  Stream<List<int>> openStream() => _socketWrapper.reader.releaseStream();

  @override
  void writeData(List<int> data) {
    _socketWrapper?.add(data);
    _socketWrapper?.flush();
  }
}

/// 代理 Connect
/// 离散化连接
class ProxyConnection extends Connection {
  ProxyConnection(this.writeDataCallback);

  final void Function(List<int> data) writeDataCallback;
  var _controller = StreamController<List<int>>();

  @override
  Future<void> checkConnection() {
    return Future.value();
  }

  @override
  void close() {
    _controller?.close();
    _controller = null;
  }

  @override
  Stream<List<int>> openStream() => _controller?.stream;

  @override
  void writeData(List<int> data) {
    return writeDataCallback(data);
  }

  /// 向流中追加数据
  void addStreamData(List<int> data) {
    _controller?.add(data);
  }
}

/// 本地代理连接
class AddressConnection extends Connection {
  AddressConnection({this.ipAddress, this.port});

  final String ipAddress;
  final int port;
  SocketWrapper _socketWrapper;

  @override
  Future<void> checkConnection() async {
    _socketWrapper ??= SocketWrapper(await Socket.connect(ipAddress, port));
  }

  @override
  void close() {
    _socketWrapper?.close();
    _socketWrapper = null;
  }

  @override
  Stream<List<int>> openStream() async* {
    yield* _socketWrapper.reader.releaseStream();
  }

  @override
  void writeData(List<int> data) {
    _socketWrapper?.add(data);
    _socketWrapper?.flush();
  }
}
