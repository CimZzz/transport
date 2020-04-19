import 'dart:async';

/// Use for get stream element by read
/// StreamReader can get one element from stream by [read] method
///
/// Design:
///
/// RawDataStream -> BroadcastStream -> Read
///
/// 1. When recv data from raw data stream, add to stream controller while pause
/// the raw data stream subscription until next read
///
/// 2. When [read] call, create broad stream if it not exists, resume the subscription
/// and return `await stream.first`.
///
/// Because the subscription had resumed, stream controller will recv new data and pause the
/// subscription again.
///
/// releaseStream:
///
/// If you need data stream instead of read again and again, call [releaseStream].  Subscription
/// will always resume and never pause again until it done. At this time, [read] return `null` forever.
///
class StreamReader2<T> {
	/// Constructor
	StreamReader2(Stream<T> rawDataStream) {
		_stream = rawDataStream.asBroadcastStream();
	}
	
	/// Broadcast Stream
	Stream<T> _stream;
	
	/// Whether stream is end (include error occur)
	var isEnd = false;
	
	/// Read first data of current data stream
	Future<T> read() =>
		isEnd ? null : _stream.first.catchError((error) {
			isEnd = true;
			return null;
		});
	
	/// Release the stream
	Stream<T> releaseStream() {
		if(isEnd) {
			return null;
		}
		isEnd = true;
		return _stream;
	}
}