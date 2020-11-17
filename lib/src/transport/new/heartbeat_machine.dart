import 'dart:async';


/// Created by CimZzz
/// 心跳机
/// 用来监控连接心跳

/// 心跳机
class HeartbeatMachine {
    HeartbeatMachine({this.interval, this.remindCount, this.timeoutCount});

    /// 心跳检查间隔
    final Duration interval;

    /// 当心跳未响应计数到达该次数时，触发 then 回调进行主动激活
    final int remindCount;

    /// 心跳超时次数
    /// 如果多次间隔检查心跳都没有收到的话，则会认定心跳超时
    final int timeoutCount;
    
    /// 上一次心跳的时间
    int _lastHeartbeatCount = 0;

    /// 心跳计时器
    Timer _beatTimer;

    /// 流订阅事件
    StreamController<void> _controller;

    /// 开始监控心跳
    Stream<void> monitor() {
      if(_controller == null) {
        _controller = StreamController();
        _beatTimer = Timer.periodic(interval, (timer) {
          _lastHeartbeatCount ++;
          if(_lastHeartbeatCount >= timeoutCount) {
            _controller.addError(Exception('心跳超时'));
            _controller.close();
          }
          else if(_lastHeartbeatCount >= remindCount) {
            _controller.add(null);
          }
         });
      }
      return _controller.stream;
    }

    /// 取消心跳机
    void cancel() {
      if(_controller == null) {
        return;
      }

      _controller.close();
      _controller = null;
      _beatTimer?.cancel();
      _beatTimer = null;
      _lastHeartbeatCount = 0;
    }

    /// 清空计数
    void clearCount() {
      _lastHeartbeatCount = 0;
    }
}