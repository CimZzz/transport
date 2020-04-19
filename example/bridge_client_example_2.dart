import 'package:transport/src/console_log_interface.dart';
import 'package:transport/src/server.dart';
import 'package:transport/src/transport/bridge/bridge_client_transaction.dart';

void main() {
  TransportServer(
    localPort: 9002,
    transaction: BridgeClientTransaction(
      logInterface: const ConsoleLogInterface(),
      topic: 'TiwZzz',
      remoteTopic: 'CimZzz',
      transportAddress: 'virtual-lightning.com',
      transportPort: 80,
      bridgeAddress: '127.0.0.1',
      bridgePort: 9000,
      rsaPublicKeyPath: '/Users/cimzzz/Documents/IDEAProjects/transport/rsa_public_key.pem',
    )
  ).startServer();
}