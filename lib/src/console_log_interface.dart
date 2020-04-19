import 'dart:math';

import 'package:console_cmd/console_cmd.dart';

import 'log_interface.dart';

class ConsoleLogInterface implements LogInterface {
	const ConsoleLogInterface();
	
	@override
	void logError(error, StackTrace stackTrace) {
		ANSIPrinter()
		..printRGB('[ERROR]: $error', fColor: 0xFF0000);
		print(stackTrace);
	}
	
	@override
	void logWarn(msg) {
		ANSIPrinter()
		..printRGB('[WARN]: $msg', fColor: 0xFFFF00);
	}
	
	@override
	void logWrong(msg) {
		ANSIPrinter()
		..printRGB('[WRONG]: $msg', fColor: 0xFF0000);
	}
	
	@override
	void logInfo(msg) {
		ANSIPrinter()
		..printRGB('[INFO]: $msg');
	}
	
}