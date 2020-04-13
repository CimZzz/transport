
abstract class TransportLogInterface {
	void logInfo(dynamic msg);

	void logError(dynamic error, StackTrace stackTrace);
}