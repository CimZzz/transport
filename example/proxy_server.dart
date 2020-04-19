import 'package:transport/transport.dart';

void main() {
	TransportServer(
		localPort: 10000,
		transaction: ProxyTransaction(
			logInterface: const ConsoleLogInterface(),
			remoteAddress: 'virtual-lightning.com',
			remotePort: 80
		)
	)
		..startServer();
}
