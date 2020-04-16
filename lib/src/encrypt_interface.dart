import 'dart:async';

abstract class EncryptInterface {
	Future<List<int>> encode(List<int> data);
	Future<List<int>> decode(List<int> data);
}