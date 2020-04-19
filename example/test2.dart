import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:transport/src/buffer_reader.dart';
import 'package:transport/src/transport/proxy/http_proxy_transaction.dart';
import 'package:transport/transport.dart';

Stream<List<int>> stream() async* {
	for(var i in [1, 2, 3, 4, 5]) {
		yield [i];
		await Future.delayed(Duration(milliseconds: 200));
	}
}


void main() async {
	final subscription = stream().listen((event) {
		print(event);
	}, onDone: () {
		print('done');
	});
	
	await Future.delayed(Duration(milliseconds: 400));
	subscription.pause();
	
	await Future.delayed(Duration(seconds: 3));
	print(3);
	subscription.resume();
	
	await Future.delayed(Duration(seconds: 10));
}