import 'dart:async';

/// Use for get stream element by read
/// StreamReader can get one element from stream by [read] method
class StreamReader<T> {
	StreamReader(this._rawStream, {void Function() onDone,}) {
		_onDone = onDone;
		_subscription = _rawStream.listen((event) {
			_controller.add(event);
			if(!_isRelease) {
				_subscription.pause();
			}
		}, onError: (error, stackTrace) {
			_controller.addError(error, stackTrace);
		}, onDone: () {
			_onDone?.call();
			if(!_isRelease) {
				_controller.sink.add(null);
			}
			_controller.sink.close();
			_subscription.cancel();
		});
	}
	final Stream<T> _rawStream;
	final StreamController<T> _controller = StreamController();
	void Function() _onDone;
	set onDone (void Function() onDone) {
		_onDone = onDone;
	}
	Stream<T> _stream;
	StreamSubscription<T> _subscription;
	
	var _isRelease = false;
	
	
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
	
	Stream<T> releaseReadStream() {
		if(_controller.isClosed) {
			return Stream.empty();
		}
		if(!_isRelease) {
			_isRelease = true;
			_subscription.resume();
		}
		return _stream ?? _controller.stream;
	}
}