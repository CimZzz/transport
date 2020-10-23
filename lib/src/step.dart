import 'dart:async';

import 'package:transport/src/proxy_completer.dart';
import 'package:transport/src/transport/server/socket_bundle.dart';

/// Base Step
abstract class BaseStep<T> {
    BaseStep(this.timeout);

    /// Step time out
    final Duration timeout;

	/// Completer
	final ProxyCompleter<T> _completer = ProxyCompleter();

	/// Step Function
	Future<T> doAction() {
		if(!_completer.isCompleted) {
			onStepAction().timeout(timeout).then((value) {
				_completer.complete(value);
			}, onError: (error, [stackTrace]) {
				_completer.complete(onStepError(error) ?? error);
			});
			
		}
		return _completer.future;
	}
	
	Future<T> onStepAction();
	
	dynamic onStepError(dynamic e) {
		return e;
	}
}

/// Base Socket Bundle Step
abstract class BaseSocketBundleStep<T> extends BaseStep<T> {
	BaseSocketBundleStep(this.socketBundle, Duration timeout) : super(timeout);

	final SocketBundle socketBundle;
}