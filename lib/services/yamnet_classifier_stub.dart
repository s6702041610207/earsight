import 'dart:typed_data';

/// ใช้แทน YamnetClassifier ตอน build เป็นเว็บ (หน้าพรีวิว UI)
/// TensorFlow Lite รันบนเว็บไม่ได้ ตัวจับเสียงจริงอยู่ในแอป Android เท่านั้น
class YamnetClassifier {
  YamnetClassifier._();

  static Future<YamnetClassifier> load() async =>
      throw UnsupportedError('AI จับเสียงทำงานเฉพาะในแอป Android');

  List<String> get labels => const [];
  String get shapeInfo => 'web preview';
  List<double> classify(Float32List waveform) => const [];
  void close() {}
}
