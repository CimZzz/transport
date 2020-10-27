import 'socket_bundle.dart';
import 'normal_step.dart';

/// Command Controller
/// Aggregate requests and responses follow in cmdIdx & respIdx, to impl async rpc
class CommandController {
    CommandController(this.socketBundle);

    /// Socket Bundle
	final SocketBundle socketBundle;

	/// Completer Map
	final Map<int, ProxyCompleterStep> completerMap = {};

	/// 建立执行结果回调
	Future doCommand(int idx) {
		if(completerMap.containsKey(idx)) {
			// 已经存在相同下标的命令，表示错误，返回 null
			return Future.value(null);
		}

		// 10 秒超时
		final step = ProxyCompleterStep(timeout: const Duration(seconds: 10));
		completerMap[idx] = step;
		return step.doAction().whenComplete(() {
			// 执行结束后，强制终止
			completerMap.remove(idx);
		});
	}

	/// 完成指令，配置结果
	void completeCommand(int idx, dynamic result) {
		if(completerMap.containsKey(idx)) {
			completerMap[idx].innerCompleter.complete(result);
		}
	}
}
