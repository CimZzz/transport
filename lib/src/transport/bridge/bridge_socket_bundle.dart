import 'dart:async';
import 'dart:io';

import '../../socket_bundle.dart';
import '../../mix_key.dart';
import 'bridge_cmd.dart';


class BridgeSlot {
	String topic;
	String subscribeTopic;
	String reqKey;
	bool doTransport;
	bool isRequest;
	MixKey mixKey;
	
	StreamSubscription timeOutSubscription;
	void Function() onTimeOut;
	
	StreamSubscription streamSubscription;
	
	void Function(BridgeSocketBundle socketBundle) onDestroy;
	
	BridgeSocketBundle proxySocket;
}

class BridgeSocketBundle extends SocketBundle<BridgeSlot> {
    BridgeSocketBundle(Socket socket) : super(socket) {
    	slot = BridgeSlot();
    }
    
    void writeCommand(BridgeCommand command) {
    	command.writeCommand(
		    byteWriter: writer,
		    mixKey: slot.mixKey
	    );
    }
    
    void wait(int timeOut, {void Function() onTimeOut}) {
	    cancelWait();
	    slot.onTimeOut = onTimeOut;
    	slot.timeOutSubscription = Future.delayed(Duration(seconds: timeOut)).asStream().listen((event) {
    		slot.onTimeOut?.call();
		    slot.timeOutSubscription?.cancel();
		    slot.timeOutSubscription = null;
	    });
    }
    
    void cancelWait() {
	    slot.onTimeOut = null;
	    slot.timeOutSubscription?.cancel();
	    slot.timeOutSubscription = null;
    }
    
    void watchStream(StreamSubscription subscription) {
	    cancelWatch();
	    slot.streamSubscription = subscription;
    }
    
    void cancelWatch() {
	    slot.streamSubscription?.cancel();
	    slot.timeOutSubscription = null;
    }

    @override
    void destroy() {
    	if(!isDestroy) {
		    cancelWait();
		    cancelWatch();
		    slot.onDestroy?.call(this);
		    slot.onDestroy = null;
		    slot.proxySocket?.destroy();
		    slot.proxySocket = null;
		    super.destroy();
	    }
    }
}