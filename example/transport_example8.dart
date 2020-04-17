import 'dart:io';
import 'package:transport/transport.dart';

void main() async {
  final localSocket = await Socket.connect('127.0.0.1', 9001);
  final localSocketWrapper = SocketWrapper(localSocket);

  localSocketWrapper.releaseStream().listen((event) {
    print('second event: $event');
  }, onError: (error, stackTrace) {
//    onError?.call(error, stackTrace);
  }, onDone: () {
    print('second done');
//    firstSocket.destroy();
    localSocketWrapper.destroy();
  }, cancelOnError: true);
}