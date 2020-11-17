/// Created by CimZzz
/// 自增整数生产器

class IntGenerator {
  var _code = 0;

  /// 生成一个整数
  int nextCode() {
    if(_code >= 0xFFFFFFFF) {
      _code = 0;
    }
    return _code ++;
  }
}