import 'dart:async';
import 'dart:typed_data';

/// ใช้แทน AudioWindowStream ตอน build เป็นเว็บ (หน้าพรีวิว UI) — ไม่เปิดไมค์
class AudioWindowStream {
  Stream<Float32List> get windows => const Stream.empty();
  Stream<double> get levels => const Stream.empty();
  bool get isRunning => false;
  Future<bool> start() async => false;
  Future<void> stop() async {}
  Future<void> dispose() async {}
}
