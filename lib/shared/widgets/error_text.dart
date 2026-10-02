/// 错误对象 -> 界面上那句话。
///
/// 工程里所有要讲给人听的地方都写 `StateError('中文话')`，而 `StateError.toString()`
/// 前面挂着「Bad state: 」这个给开发者看的前缀 —— 直接摆到错误页上很突兀。
/// 拆掉它，只留那句话。
///
/// 其余错误原样透出：接口给的 404、超时之类虽然不好看，但至少比笼统的
/// 「出错了」多些线索，回头用户报问题时也对得上。
String errorText(Object error) {
  // StateError.message 本来就是 String，不用再判类型。
  if (error is StateError && error.message.trim().isNotEmpty) {
    return error.message;
  }
  return '$error';
}
