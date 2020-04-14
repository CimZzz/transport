import '../lib/src/console_log_interface.dart';
import '../lib/src/proxy/proxy_server.dart';

void main() async {
  final server = TransportProxyServer(
      localPort: 4444,
      remoteAddress: 'virtual-lightning.com',
      remotePort: 80
  );
  server.logInterface = ConsoleLogInterface();
  server.startServer();
}
