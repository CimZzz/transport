import 'dart:convert';
import 'dart:io';

void main() async {
  final socket = await Socket.connect('127.0.0.1', 8002);
//  print(await wrapper.readOneByte());
//  final dataList = await wrapper.releaseStream().reduce((previous, element) => previous += element);
  final dataList = await socket.reduce((previous, element) => previous += element);
  print(utf8.decode(dataList));
  socket.destroy();
}