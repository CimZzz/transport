
import 'dart:async';

var control = Completer();

Stream<int> _stream1() async* {
  for(var i = 0 ; i < 20 ; i ++) {
    yield i;
  }
}

Stream<int> _stream2() async* {
  await for(var i  in _stream1()) {
    yield i;
  }
}

void main() async {
  cat();
}


void cat() async {
  await for(var s in _stream2()) {
    print(s);
    await Future.delayed(const Duration(milliseconds: 500));
  }
}