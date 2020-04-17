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
	StreamReader(this._rawStream, {void Function() onDone,}) {
		_onDone = onDone;

		// Raw data stream subscription
		_subscription = _rawStream.listen((event) {
			_controller.add(event);
			// if not release, pause the subscription
			if(!_isRelease) {
				_subscription.pause();
			}
		}, onError: (error, stackTrace) {
			// add error to controller
			_controller.addError(error, stackTrace);
		}, onDone: () {
			// onDone callback call(if exists)
			_onDone?.call();
			// if not release, add `null` to StreamController, because may be someone wait [read], must
			if(!_isRelease) {
				_controller.add(null);
			}
			// close StreamController
			_controller.close();
			// Cancel subscription
			_subscription.cancel();
		}, cancelOnError: true);
	}

	/// Raw data stream
	final Stream<T> _rawStream;

	/// Stream controller
	final StreamController<T> _controller = StreamController();

	/// onDone callback
	void Function() _onDone;
	set onDone (void Function() onDone) {
		_onDone = onDone;
	}

	/// Inner broadcast stream of Stream controller's stream
	Stream<T> _stream;

	/// Stream subscription
	StreamSubscription<T> _subscription;

	/// Whether the stream is released
	var _isRelease = false;

	/// Read first data of current data stream
	Future<T> read() async {
		if(_isRelease) {
			return null;
		}
		_stream ??= _controller.stream.asBroadcastStream();
		_subscription.resume();
		if(_controller.isClosed) {
			return null;
		}
		return await _stream.first;
	}

	/// Release the stream
	Stream<T> releaseStream() {
		// if controller is closed, return empty stream
		if(_controller.isClosed) {
			return Stream.empty();
		}
		if(!_isRelease) {
			_isRelease = true;
			_subscription.resume();
		}
		return _stream ?? _controller.stream;
	}

	/// Destroy the stream reader
	void destroy() {
		// if controller is closed, return
		if(_controller.isClosed) {
			return;
		}
		_subscription.cancel();
		_controller.add(null);
		_controller.close();
	}
}