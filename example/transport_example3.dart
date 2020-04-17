import 'package:transport/transport.dart';

void main() async {
  final bridge = TransportBridgeServer(localPort: 8000);
  bridge.logInterface = ConsoleLogInterface();
  await bridge.startServer();
}