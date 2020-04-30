import 'package:transport/transport.dart';

void main() {
  TransportServer(
    localPort: 9001,
    transaction: BridgeClientTransaction(
      logInterface: const ConsoleLogInterface(),
      topic: 'CimZzz',
      remoteTopic: 'TiwZzz',
      peerAddress: 'virtual-lightning.com',
      peerPort: 80,
      isPeerCustomTransport: true,
      bridgeAddress: '127.0.0.1',
      bridgePort: 9000,
      rsaPublicKeyPath: '/Users/wangyanxiong/Documents/IDEAProject/transport/rsa_public_key.pem',
    )
  ).startServer();
}