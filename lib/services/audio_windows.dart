import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:record/record.dart';

/// อ่านเสียงจากไมค์เป็น PCM 16 kHz mono แล้วตัดเป็นหน้าต่างขนาดที่ YAMNet ต้องการ
///
/// - หน้าต่างละ 15,600 sample (0.975 วินาที)
/// - เลื่อนทีละ 7,800 sample (ซ้อนกัน 50%) → ได้ผลใหม่ทุก ~0.49 วินาที
/// - เสียงอยู่ในหน่วยความจำชั่วคราวเท่านั้น ไม่เขียนลงไฟล์
class AudioWindowStream {
  static const int sampleRate = 16000;
  static const int windowSize = 15600;
  static const int hopSize = 7800;

  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sub;
  final List<double> _buffer = [];
  int? _carryByte;

  final _windows = StreamController<Float32List>.broadcast();
  final _levels = StreamController<double>.broadcast();

  /// หน้าต่างเสียงพร้อมส่งเข้าโมเดล (ค่า -1..1)
  Stream<Float32List> get windows => _windows.stream;

  /// ความดังโดยประมาณ 0..1 สำหรับแถบระดับเสียงบนหน้าจอ
  Stream<double> get levels => _levels.stream;

  bool get isRunning => _sub != null;

  /// คืน false ถ้าผู้ใช้ไม่อนุญาตไมโครโฟน
  Future<bool> start() async {
    if (isRunning) return true;
    if (!await _recorder.hasPermission()) return false;
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: sampleRate,
      numChannels: 1,
    ));
    _sub = stream.listen(_onBytes);
    return true;
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    if (await _recorder.isRecording()) await _recorder.stop();
    _buffer.clear();
    _carryByte = null;
    _levels.add(0);
  }

  void _onBytes(Uint8List chunk) {
    var bytes = chunk;
    if (_carryByte != null) {
      bytes = Uint8List(chunk.length + 1)
        ..[0] = _carryByte!
        ..setRange(1, chunk.length + 1, chunk);
      _carryByte = null;
    }
    final evenLen = bytes.length & ~1;
    if (evenLen < bytes.length) _carryByte = bytes[bytes.length - 1];

    final data = ByteData.sublistView(bytes, 0, evenLen);
    var sumSq = 0.0;
    final n = evenLen ~/ 2;
    for (var i = 0; i < n; i++) {
      final s = data.getInt16(i * 2, Endian.little) / 32768.0;
      _buffer.add(s);
      sumSq += s * s;
    }
    if (n > 0) {
      final rms = math.sqrt(sumSq / n);
      _levels.add((rms * 4).clamp(0.0, 1.0));
    }

    while (_buffer.length >= windowSize) {
      _windows.add(Float32List.fromList(_buffer.sublist(0, windowSize)));
      _buffer.removeRange(0, hopSize);
    }
  }

  Future<void> dispose() async {
    await stop();
    await _recorder.dispose();
    await _windows.close();
    await _levels.close();
  }
}
