
import 'package:transport/src/buffer_reader.dart';

import '../encrypt_interface.dart';

class VLEncrypt implements EncryptInterface {
	@override
	Stream<List<int>> decode(Stream<List<int>> dataStream) async* {
		final reader = BufferReader(rawStream: dataStream);
	}
	
	@override
	Stream<List<int>> encode(Stream<List<int>> dataStream) async* {
		final reader = BufferReader(rawStream: dataStream);
	}
}
