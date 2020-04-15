import '../lib/src/console_log_interface.dart';
import '../lib/src/proxy/proxy_server.dart';
import 'package:pedantic/pedantic.dart';

void main() async {
  final server = TransportProxyServer(
      localPort: 4444,
      remotePort: 8002
  );
  server.logInterface = ConsoleLogInterface();
  unawaited(server.startServer());
}
