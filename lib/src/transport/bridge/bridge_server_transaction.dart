import 'dart:io';

import '../..//server.dart';
import '../../log_interface.dart';

class BridgeServerTransaction extends ServerTransaction {
	
	BridgeServerTransaction({LogInterface logInterface}) :
			super(logInterface: logInterface);
	
	
	@override
	void handleSocket(Socket socket) {
	}
}