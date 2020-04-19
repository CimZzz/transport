import 'dart:async';
import 'dart:isolate';

typedef ComputeCallback<Q, R> = FutureOr<R> Function(Q message);

class IsolateRunner {
	IsolateRunner._();

	static Future<E> execute<T, E>(T message, {
		ComputeCallback<T, E> runner
	}) async {
		final recvPort = ReceivePort();
		final isolate = await Isolate.spawn<_IsolateBundle<T, E>>(_isolateEntryPoint, _IsolateBundle<T, E>(
			runner: runner,
			message: message,
			sendPort: recvPort.sendPort,
		), onError: recvPort.sendPort, errorsAreFatal: true);
		final completer = Completer<E>();
		
		recvPort.listen((event) {
			completer.complete(event);
		}, onError: (e, stackTrace) {
			completer.completeError(e, stackTrace);
		}, onDone: () {
			recvPort.close();
			isolate.kill();
		});

		return await completer.future;
	}
}

class _IsolateBundle<T, E> {
	const _IsolateBundle({this.runner, this.message, this.sendPort});

	final ComputeCallback<T, E> runner;
	final T message;
	final SendPort sendPort;

	FutureOr<E> apply() => runner(message);
}

void _isolateEntryPoint<T, E>(_IsolateBundle<T, E> bundle) async {
	final result = await bundle.apply();
	bundle.sendPort.send(result);
}