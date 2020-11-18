import 'package:transport/src/transport/new/response_socket.dart';

void main([List<String> args]) async {
  ResponseSocket.bindBridge(
      option: ResponseSocketOption(registrar: {
    ResponseRegistrar(clientId: 'CimZzz', ipAddress: '0.0.0.0', port: 10088)
  }));
}
