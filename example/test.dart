import 'package:transport/src/console_log_interface.dart';
import 'package:transport/src/server.dart';
import 'package:transport/src/transport/proxy/proxy_transaction.dart';

void main() async {
	TransportServer(
		localPort: 9999,
		transaction: ProxyTransaction(
			logInterface: const ConsoleLogInterface(),
			remoteAddress: 'virtual-lightning.com',
			remotePort: 80
		)
	)
	..startServer();
}