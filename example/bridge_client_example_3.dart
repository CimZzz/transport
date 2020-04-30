import 'package:transport/transport.dart';

void main() {
  TransportServer(
    localPort: 10086,
    transaction: BridgeClientTransaction(
      logInterface: const ConsoleLogInterface(),
      topic: 'CimZzz',
      remoteTopic: 'HeJian',
      transportAddress: 'virtual-lightning.com',
      transportPort: 80,
      bridgeAddress: '49.234.99.78',
      bridgePort: 10086,
    )
  ).startServer();
}