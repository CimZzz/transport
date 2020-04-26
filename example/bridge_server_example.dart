import 'package:transport/transport.dart';

void main() {
	TransportServer(
		localPort: 9000,
		transaction: BridgeServerTransaction(
			logInterface: const ConsoleLogInterface(),
			rsaPrivateKeyPath: '/Users/wangyanxiong/Documents/IDEAProject/transport/rsa_private_key.pem',
		)
	).startServer();
}