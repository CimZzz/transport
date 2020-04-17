import '../buffer_reader.dart';
import '../encrypt_interface.dart';

class VLEncrypt {
	factory VLEncrypt() => const VLEncrypt._();
	const VLEncrypt._();

	@override
	Stream<List<int>> decode(Stream<List<int>> dataStream) async* {
		final reader = BufferReader(rawStream: dataStream);
		while(!reader.isClosed) {
			final bytes = await reader.readAnyBytesList();
			if(bytes != null) {
				yield bytes;
			}
		}
	}

	@override
	Stream<List<int>> encode(Stream<List<int>> dataStream) async* {
		final reader = BufferReader(rawStream: dataStream);
		while(!reader.isClosed) {
			final bytes = await reader.readAnyBytesList();
			if(bytes != null) {
				yield bytes;
			}
		}
	}
}
