import 'dart:async';
import 'dart:convert';

import 'package:transport/src/transport/proxy/http_proxy_transaction.dart';
import 'package:transport/transport.dart';

Stream<List<int>> stream() async* {
	yield utf8.encode('奥术大师多\rasd\nasas');
}


void main() {
	TransportServer(
		localPort: 10000,
		transaction: HttpProxyTransaction(
			logInterface: const ConsoleLogInterface(),
			bridgeClientPort: 9001
		)
	)
		..startServer();
}