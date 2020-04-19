import 'dart:async';
import 'dart:io';

import '../transport.dart';

/// Transport Server Config
/// About Server port configuration
class TransportServerConfig {
    TransportServerConfig(this.localPort);
    
	final int localPort;
}

/// Transport server
class TransportServer {
	
	/// Constructor
	/// Cannot extends it
	factory TransportServer({int localPort, ServerTransaction transaction}) =>
		TransportServer._(localPort: localPort, transaction: transaction);
	
	TransportServer._({this.localPort, ServerTransaction transaction})
		: _transaction = transaction {
		transaction._transportServer = this;
	}
	
	/// Local server bind
	final int localPort;
	
	/// Server transaction
	final ServerTransaction _transaction;
	
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
		await _transaction.onBeforeServerStart();
		_serverSocket = await ServerSocket.bind('127.0.0.1', localPort);
		_serverSocket.listen((socket) async {
			acceptSocket(socket);
		}, onError: (e, stackTrace) {
			_transaction.logError(e, stackTrace);
			closeServer();
		});
		await _transaction.onAfterServerStarted();
		return;
	}
	
	/// Close server
	Future<void> closeServer() async {
		if (isRunning) {
			_isRunning = false;
			try {
				await _transaction.onBeforeServerClose();
				await _serverSocket.close();
				await _transaction.onAfterServerClosed();
			}
			catch (e, stackTrace) {
				_transaction.logError(e, stackTrace);
			}
		}
		return;
	}
	
	/// Close server
	void destroyServer() {
		closeServer();
	}
	
	/// Receiver socket
	void acceptSocket(Socket socket) {
		_transaction.handleSocket(socket);
	}
}

/// Handle socket from server
abstract class ServerTransaction {
	ServerTransaction({LogInterface logInterface}):
			_logInterface = logInterface;
	
	/// Instance of server
	TransportServer _transportServer;
	
	/// Local server port getter
	int get localPort => _transportServer?.localPort;
	
	/// Whether local server is running
	bool get isRunning => _transportServer?.isRunning;
	
	/// Destroy server
	void destroyServer() {
		_transportServer?.destroyServer();
	}
	
	/// Whether print log
	static bool DO_LOG = true;
	bool get needLog => ServerTransaction.DO_LOG;
	
	/// log interface, receive log and decide how to handle it
	final LogInterface _logInterface;
	
	/// Log info
	void logInfo(dynamic msg) {
		if(needLog) {
			_logInterface?.logInfo(msg);
		}
	}
	
	/// Log warn
	void logWarn(dynamic msg) {
		if(needLog) {
			_logInterface?.logWarn(msg);
		}
	}
	
	/// Log wrong
	void logWrong(dynamic msg) {
		if(needLog) {
			_logInterface?.logWrong(msg);
		}
	}
	
	/// Log error
	void logError(dynamic error, StackTrace stackTrace) {
		if(needLog) {
			_logInterface?.logError(error, stackTrace);
		}
	}
	
	/// *** Server life-time Function ***
	
	/// Call this function before server start
	Future<void> onBeforeServerStart() => null;
	
	/// Call this function after server started
	Future<void> onAfterServerStarted() => null;
	
	/// Call this function when server recv a new socket
	/// * Fetch socket data and process, do sth you want
	void handleSocket(Socket socket);
	
	/// Call this function before server close
	Future<void> onBeforeServerClose() => null;
	
	/// Call this function after server closed
	Future<void> onAfterServerClosed() => null;
}