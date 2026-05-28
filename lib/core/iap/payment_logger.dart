import 'package:flutter/foundation.dart';

/// 支付流程可见日志 — 收集日志条目供 UI 展示
class PaymentLogger {
  PaymentLogger._();
  static final PaymentLogger instance = PaymentLogger._();

  final List<LogEntry> _entries = [];
  final List<VoidCallback> _listeners = [];

  List<LogEntry> get entries => List.unmodifiable(_entries);

  void addListener(VoidCallback cb) => _listeners.add(cb);
  void removeListener(VoidCallback cb) => _listeners.remove(cb);

  void log(String tag, String message) {
    final entry = LogEntry(
      time: DateTime.now(),
      tag: tag,
      message: message,
    );
    _entries.add(entry);
    debugPrint('[PayLog] ${entry.short}');
    for (final cb in _listeners) {
      cb();
    }
  }

  void clear() {
    _entries.clear();
    for (final cb in _listeners) {
      cb();
    }
  }
}

class LogEntry {
  final DateTime time;
  final String tag;
  final String message;

  const LogEntry({required this.time, required this.tag, required this.message});

  String get short => '${time.toIso8601String().substring(11, 19)} [$tag] $message';

  String get display {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    final ms = time.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms [$tag] $message';
  }
}
