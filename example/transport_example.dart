

import 'package:transport/src/proxy_server.dart';

void main() {
  final server = TransportProxyServer(localPort: 4444, remoteAddress: 'virtual-lightning.com', remotePort: 80);
  server.startServer();
}
