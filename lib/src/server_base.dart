import 'dart:async';
import 'dart:io';
import 'log_interface.dart';

/// Abstract transport server
abstract class BaseServer {
	/// Constructor
	BaseServer({this.localPort});
	
	/// Local server bind
	final int localPort;
	
	/// Local server socket
	/// Listen specify port and accept socket
	ServerSocket _serverSocket;
	
	/// Whether server is running
	bool _isRunning = false;
	
	/// Whether the server is running
	bool get isRunning => _isRunning;

	/// Start local server
	Future<void> startServer() async {
		if (isRunning) {
			return;
		}
		_isRunning = true;
		_serverSocket = await ServerSocket.bind('127.0.0.1', localPort);
		_serverSocket.listen((socket) async {
			acceptSocket(socket);
		}, onError: (e, stackTrace) {
			logError(e, stackTrace);
			logInfo('server down');
			closeServer();
		});
		return;
	}
	
	/// Close server
	Future<void> closeServer() async {
		if (isRunning) {
			_isRunning = false;
			try {
				await _serverSocket.close();
			}
			catch (e, stackTrace) {
				logError(e, stackTrace);
			}
			return;
		}
		return;
	}
	
	/// Close server
	void destroyServer() {
		closeServer();
	}

	/// Receiver socket
	void acceptSocket(Socket socket);
	
	/// Log interface
	LogInterface _logInterface;
	set logInterface(LogInterface interface) {
		_logInterface = interface;
	}
	
	/// Log info
	void logInfo(dynamic msg) {
		_logInterface?.logInfo(msg);
	}
	
	/// Log warn
	void logWarn(dynamic msg) {
		_logInterface?.logWarn(msg);
	}
	
	/// Log wrong
	void logWrong(dynamic msg) {
		_logInterface?.logWrong(msg);
	}
	
	/// Log error
	void logError(dynamic error, StackTrace stackTrace) {
		_logInterface?.logError(error, stackTrace);
	}
}