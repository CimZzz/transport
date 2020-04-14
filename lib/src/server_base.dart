import 'dart:async';
import 'log_interface.dart';

/// Abstract transport server
abstract class BaseServer {

	LogInterface _logInterface;

	set logInterface(LogInterface interface) {
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