abstract class MessageHandler {
  /// Translates a message from main Isolate to a method call on this instance.
  ///
  /// Returns `true` if have been translated successfully,
  /// returns `false` if the message should be propagated to another handler.
  Future<bool> handleMessage(Map message);
}