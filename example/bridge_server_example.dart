import 'package:transport/src/console_log_interface.dart';
import 'package:transport/src/server.dart';
import 'package:transport/src/transport/bridge/bridge_client_transaction.dart';
import 'package:transport/src/transport/bridge/bridge_server_transaction.dart';

void main() {
	TransportServer(
		localPort: 9000,
		transaction: BridgeServerTransaction(
			logInterface: const ConsoleLogInterface(),
			rsaPrivateKeyPath: '/Users/wangyanxiong/Documents/IDEAProject/transport/rsa_private_key.pem',
		)
	).startServer();
}