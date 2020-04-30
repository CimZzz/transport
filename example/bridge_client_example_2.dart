import 'package:transport/transport.dart';

void main() {
  TransportServer(
    localPort: 9002,
    transaction: BridgeClientTransaction(
      logInterface: const ConsoleLogInterface(),
      topic: 'TiwZzz',
      remoteTopic: 'CimZzz',
      bridgeAddress: '127.0.0.1',
      bridgePort: 9000,
      rsaPublicKeyPath: '/Users/wangyanxiong/Documents/IDEAProject/transport/rsa_public_key.pem',
    )
  ).startServer();
}