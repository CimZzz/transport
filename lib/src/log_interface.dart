
abstract class LogInterface {
	void logInfo(dynamic msg);
	
	void logWarn(dynamic msg);
	
	void logWrong(dynamic msg);
	
	void logError(dynamic error, StackTrace stackTrace);
}