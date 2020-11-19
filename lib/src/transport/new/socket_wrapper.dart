/// Created by CimZzz
/// Socket 包装器
/// 包含多种 Socket 信息，方便快速查询使用

import 'dart:io';

import 'package:stream_data_reader/stream_data_reader.dart';
import 'package:transport/src/proxy_completer.dart';

class SocketWrapper {
  SocketWrapper(this.socket, {ByteBufferReader reader})
      : address = socket.address.address,
        port = socket.port,
        reader = DataReader(reader ?? ByteBufferReader(StreamReader(socket)));

  /// Socket 对象
  final Socket socket;

  /// Socket 地址
  final String address;

  /// Socket 端口
  final int port;

  /// Socket Reader
  DataReader reader;

  /// Socket 写入失败回调 Completer
  ProxyCompleter writeError = ProxyCompleter();

  /// 写入数据 Buffer
  List<int> _writeBuffer;

  /// 判断是否正在 Flushing
  var _isFlushing = false;

  /// 判断是否仍需要 flush
  var _isNeedFlush = false;

  /// 判断是否需要请求关闭 Socket
  var _isRequestClosed = false;

  /// 判断是否已经关闭
  var _isClosed = false;

  /// 写入单字节
  void writeByte(int byte) {
    add([byte & 0xFF]);
  }

  /// 写入短整型数据
  void writeShort(int num, {bool bigEndian = true}) {
    if (bigEndian) {
      add([(num >> 8) & 0xFF, num & 0xFF]);
    } else {
      add([num & 0xFF, (num >> 8) & 0xFF]);
    }
  }

  /// 写入整型数据
  void writeInt(int num, {bool bigEndian = true}) {
    if (bigEndian) {
      add([
        (num >> 24) & 0xFF,
        (num >> 16) & 0xFF,
        (num >> 8) & 0xFF,
        num & 0xFF
      ]);
    } else {
      add([
        num & 0xFF,
        (num >> 8) & 0xFF,
        (num >> 16) & 0xFF,
        (num >> 24) & 0xFF
      ]);
    }
  }

  /// 写入字节数据
  void add(List<int> data) {
    if (!_isFlushing) {
      if (_writeBuffer != null) {
        socket.add(_writeBuffer);
        _writeBuffer = null;
      }
      socket.add(data);
    } else {
      _writeBuffer ??= [];
      _writeBuffer.addAll(data);
    }
  }

  /// flush
  void flush() {
    if (_isRequestClosed) {
      return;
    }
    if (!_isFlushing) {
      _isFlushing = true;
      _isNeedFlush = false;
      if (_writeBuffer != null) {
        socket.add(_writeBuffer);
        _writeBuffer = null;
      }
      socket.flush().then((_) {
        // flush 完成
        _isFlushing = false;
        if (_isRequestClosed) {
          close();
          return;
        }
        if (_isNeedFlush) {
          flush();
        }
      }, onError: (error, stackTrace) {
        // flush 发生异常
        print('发生异常！！！！: $error');
        // writeError.completeError(error, stackTrace);
        _isFlushing = false;
        if (_isRequestClosed) {
          close();
          return;
        }
      });
    } else {
      _isNeedFlush = true;
    }
  }

  /// 关闭当前连接
  void close() {
    _isNeedFlush = false;
    _isRequestClosed = true;
    if (!_isFlushing) {
      if (!_isClosed) {
        _isClosed = true;
        socket.close().catchError((error) {});
        socket.destroy();
      }
    }
  }
}
