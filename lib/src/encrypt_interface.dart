import 'dart:async';

abstract class EncryptInterface {
	Stream<List<int>> encode(Stream<List<int>> dataStream);
	Stream<List<int>> decode(Stream<List<int>> dataStream);
}