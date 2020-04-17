import 'package:transport/transport.dart';

void main() async {
  final server = TransportClientServer(
      localPort: 8001,
      topic: 'CimZzz',
      remoteTopic: 'TiwZzz',
      transportPort: 9001,
      bridgeAddress: '127.0.0.1',
      bridgePort: 8000
  );
  server.logInterface = ConsoleLogInterface();
  await server.startServer();
}