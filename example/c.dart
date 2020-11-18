import 'package:transport/src/transport/new/request_socket.dart';

void main() {
  RequestServer.listen(
      option: RequestServerOption(
          ipAddress: '0.0.0.0',
          port: 10088,
          clientId: 'CimZzz',
          localPort: 10089,
          proxyIpAddress: 't.gogoh5.com',
          proxyPort: 9000));
}
