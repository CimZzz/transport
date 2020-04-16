import '../lib/src/console_log_interface.dart';
import '../lib/src/proxy/proxy_server.dart';
import 'package:pedantic/pedantic.dart';

void main() async {
  final server = TransportProxyServer(
      localPort: 10000,
      allowCache: false,
      remotePort: 5037
  );
  server.logInterface = ConsoleLogInterface();
  unawaited(server.startServer());
}
