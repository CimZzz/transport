import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:transport/src/buffer_reader.dart';
import 'package:transport/src/transport/proxy/http_proxy_transaction.dart';
import 'package:transport/transport.dart';

Stream<List<int>> stream() async* {
	for(var i in [1, 2, 3, 4, 5]) {
		yield [i];
		await Future.delayed(Duration(seconds: 1));
	}
}


void main() async {
	final reader = BufferReader(rawStream: stream());
	print(await reader.readAnyBytesList());
	await Future.delayed(Duration(seconds: 6));
	print(await reader.readAnyBytesList());
	print(await reader.readAnyBytesList());
	print(await reader.readAnyBytesList());
	print(await reader.readAnyBytesList());
	print(await reader.readAnyBytesList());
}