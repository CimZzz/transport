import 'dart:async';

/// Use for get stream element by read
/// StreamReader can get one element from stream by [read] method
///
/// Design:
///
/// RawDataStream -> StreamController => BroadcastStream -> Read
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
class StreamReader<T> {
	/// Constructor
	StreamReader(Stream<T> rawDataStream) {
		_subscription = rawDataStream.listen((event) {
			if(_isRelease) {
				// stream released, add to controller directly
				_releaseController.add(event);
			}
			else {
				// read waiting, add to completer
				_readCompleter.complete(event);
				_readCompleter = null;
				_subscription.pause();
			}
		}, onError: (error, stackTrace) {
			if(_isRelease) {
				// stream released, add error to controller
				_releaseController.addError(error, stackTrace);
			}
			else {
				// read waiting, add error to completer
				_readCompleter.completeError(error, stackTrace);
				_readCompleter = null;
			}
		}, onDone: () {
			destroy();
		});
		_subscription.pause();
	}
	
	/// Stream Subscription
	StreamSubscription<T> _subscription;
	
	/// Stream Controller
	StreamController<T> _releaseController;
	
	/// Read Completer
	Completer<T> _readCompleter;
	
	/// Whether stream is released
	var _isRelease = false;
	
	/// Whether stream is end
	var _isEnd = false;
	bool get isEnd => _isEnd;
	
	/// Whether stream is end (include error occur)
	
	/// Read first data of current data stream
	/// If stream is released or end, return null
	Future<T> read() async {
		if(_isEnd || _isRelease) {
			return null;
		}
		
		if(_readCompleter == null) {
			_readCompleter = Completer();
			_subscription.resume();
		}
		
		return _readCompleter.future;
	}
	
	/// Release the stream
	/// If stream is released or end, return null
	/// If current is waiting for reading, complete `null` directly
	Stream<T> releaseStream() {
		if(_isEnd || _isRelease) {
			return null;
		}
		_isRelease = true;
		_subscription.resume();
		if(_readCompleter != null) {
			_readCompleter.complete(null);
			_readCompleter = null;
		}
		_releaseController = StreamController();
		return _releaseController.stream;
	}
	
	/// Destroy StreamReader
	void destroy() {
		if(!_isEnd) {
			_isEnd = true;
			if(_isRelease) {
				// stream released, close controller
				_releaseController.close();
			}
			else if(_readCompleter != null) {
				// if wait reading now, complete `null`
				_readCompleter.complete(null);
				_readCompleter = null;
			}
			_subscription.cancel();
		}
	}
}