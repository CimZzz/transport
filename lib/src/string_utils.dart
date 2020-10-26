

import 'package:transport/src/transport/server/socket_bundle.dart';

/// String Utils
class StringUtils {
	StringUtils._();

	/// Convert socketType(int) to brief(String)
	static String getSocketTypeStr(int socketType) {
		switch(socketType) {
			case kSocketTypeControl:
				return 'Control';
			case kSocketTypeRequest:
				return 'Request';
			case kSocketTypeResponse:
				return 'Response';
			default:
				return 'Unknown';
		}
	}

}