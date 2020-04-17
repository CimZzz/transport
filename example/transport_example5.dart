import 'package:transport/transport.dart';

void main() async {
  final server = TransportClientServer(
      localPort: 8002,
      topic: 'TiwZzz',
      remoteTopic: 'CimZzz',
      transportAddress: 'virtual-lightning.com',
      transportPort: 80,
      bridgeAddress: '127.0.0.1',
      bridgePort: 8000
  );
  server.logInterface = ConsoleLogInterface();
  await server.startServer();
}