import 'dart:async';


/// Stream occur error callback
typedef onStreamError<T> = void Function(StreamTransport<T> transport, dynamic error, [StackTrace stackTrace]);

/// Stream transport done callback
typedef onStreamDone<T> = void Function(StreamTransport<T> transport, StreamTransport otherTransport);

/// Stream transport inner done callback
typedef _onStreamInnerDone = void Function();

/// Recv other stream data callback
typedef onRecvStreamData<T> = Future<void> Function(StreamTransport<T> transport, List<int> data);

/// Transport stream data
class StreamTransport<T> {
	StreamTransport (
		Stream<List<int>> dataStream, {
		T bindData,
		onStreamError<T> streamError,
		onStreamDone<T> streamDone,
		onRecvStreamData<T> recvStreamData,
	})
		: _stream = dataStream,
			_slot = bindData,
			_streamError = streamError,
			_streamDone = streamDone,
			_recvStreamData = recvStreamData;
	
	/// Raw data stream
	final Stream<List<int>> _stream;
	
	/// Slot of StreamTransport
	final T _slot;
	
	/// Slot getter
	T get slot => _slot;
	
	final onStreamError<T> _streamError;
	final onStreamDone<T> _streamDone;
	final onRecvStreamData<T> _recvStreamData;
	_onStreamInnerDone _innerStreamDone;
	
	/// Raw data stream subscription
	StreamSubscription _subscription;
	
	/// Other side transport
	StreamTransport _otherTransport;
	
	/// Whether is transporting
	var _isTransport = false;
	
	/// Whether is done
	var _isDone = false;
	
	/// Destroy this StreamTransport
	void destroy() {
		if(!_isDone) {
			_isDone = true;
			_subscription?.cancel();
			_streamDone?.call(this, _otherTransport);
			_innerStreamDone?.call();
		}
	}
	
	/// Transport data to other transport
	void transportToTransport(StreamTransport otherTransport) {
		if(_isTransport || _isDone || (otherTransport._isTransport && otherTransport._otherTransport != this)) {
			destroy();
			return;
		}
		_isTransport = true;
		_otherTransport = otherTransport;
		if(otherTransport._recvStreamData != null) {
			_subscription = _stream.listen((data) async {
				try {
					await otherTransport._recvStreamData(
						otherTransport, data);
				}
				catch(e, stackTrace) {
					_streamError?.call(e, stackTrace);
					destroy();
					otherTransport.destroy();
				}
			}, onError: (e, stackTrace) {
				_streamError?.call(this, e, stackTrace);
			}, onDone: () {
				destroy();
			});
		}
	}
}