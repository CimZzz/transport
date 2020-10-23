import 'dart:async';

/// Proxy Completer
/// Complete once safety
class ProxyCompleter<T> implements Completer<T> {
	/// Inner Completer
	final Completer<T> _completer = Completer();

	@override
	void complete([FutureOr<T> value]) {
		if(!_completer.isCompleted) {
			_completer.complete(value);
		}
	}

	@override
	void completeError(Object error, [StackTrace stackTrace]) {
		if(!_completer.isCompleted) {
			_completer.completeError(error, stackTrace);
		}
	}

	@override
	Future<T> get future => _completer.future;

	@override
	bool get isCompleted => _completer.isCompleted;

}