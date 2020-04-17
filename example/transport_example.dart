
import 'package:pedantic/pedantic.dart';
import 'package:transport/transport.dart';

void main() async {
  final server = TransportProxyServer(
      localPort: 10000,
      allowCache: false,
      remotePort: 5037
  );
  server.logInterface = ConsoleLogInterface();
  unawaited(server.startServer());
}
