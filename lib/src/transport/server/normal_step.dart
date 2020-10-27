import 'dart:async';

import 'package:transport/src/proxy_completer.dart';
import 'package:transport/src/step.dart';

class ProxyCompleterStep<T> extends BaseStep<T> {
    ProxyCompleterStep({Duration timeout}) : super(timeout);

	final ProxyCompleter<T> innerCompleter = ProxyCompleter();

    @override
    Future<T> onStepAction() async {
    	return await innerCompleter.future;
    }
}