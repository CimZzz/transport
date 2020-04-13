import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'log_interface.dart';

/// Abstract transport server
abstract class TransportServer {

	TransportLogInterface _logInterface;

	set logInterface(TransportLogInterface interface) {
		_logInterface = interface;
	}

	void logInfo(dynamic msg) {
		_logInterface?.logInfo(msg);
	}

	void logError(dynamic error, StackTrace stackTrace) {
		_logInterface?.logError(error, stackTrace);
	}

	/// Whether the server is running
	bool get isRunning;

	/// Start source server
	Future<void> startServer();

	/// Close server
	Future<void> closeServer();
}

/// Transport socket data
void transportSocket(Socket srcSocket, Future<Socket> Function() remoteSocketCreator, {
  void Function(dynamic error, [StackTrace stackTrace]) onError,
  Future<List<int>> Function(List<int>) encodeCallback,
  Future<List<int>> Function(List<int>) decodeCallback,
}) {
  Socket remoteSocket;
  StreamSubscription remoteSubscription;
  srcSocket.listen((Uint8List event) async {
    try {
      if(remoteSocket == null) {
        remoteSocket = await remoteSocketCreator();
        remoteSubscription = remoteSocket.listen((event) async {
          try {
            if(decodeCallback != null) {
              srcSocket.add(await decodeCallback(event));
            }
            else {
              srcSocket.add(event);
            }
          }
          catch(e, stackTrace) {
            // transfer data occur error
            onError?.call(e, stackTrace);
          }
        }, onError: onError ?? (e, stackTrace) {
          // occur error
        }, onDone: () {
          remoteSubscription?.cancel();
          remoteSubscription = null;
          remoteSocket = null;
        });
      }
      if(encodeCallback != null) {
        remoteSocket.add(await encodeCallback(event));
      }
      else {
        remoteSocket.add(event);
      }
    }
    catch(e, stackTrace) {
      // transfer data occur error
      onError?.call(e, stackTrace);
    }
  }, onError: onError ?? (e, stackTrace) {
    // occur error
  }, onDone: () {
    // completed
    remoteSubscription?.cancel();
    remoteSocket?.destroy();
    remoteSubscription = null;
    remoteSocket = null;
  });
}