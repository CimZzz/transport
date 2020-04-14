
abstract class LogInterface {
	void logInfo(dynamic msg);

	void logError(dynamic error, StackTrace stackTrace);
}