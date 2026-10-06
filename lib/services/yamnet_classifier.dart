import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:tflite_flutter/tflite_flutter.dart';

import '../core/categories.dart';

/// ห่อโมเดล YAMNet (TensorFlow Lite) ที่รันบนเครื่อง
///
/// รองรับโมเดลได้ 2 แบบ:
/// - YAMNet classification (TFLite Task Library): input [1, 15600] → output [1, 521]
/// - YAMNet แบบเต็ม: input [15600] (dynamic) → output scores [N, 521]
/// ถ้ามีหลายเฟรม จะใช้คะแนนสูงสุดของแต่ละคลาส
class YamnetClassifier {
  YamnetClassifier._(this._interpreter, this.labels);

  static const modelAsset = 'assets/models/yamnet.tflite';
  static const labelsAsset = 'assets/models/yamnet_class_map.csv';
  static const inputSamples = 15600;

  final Interpreter _interpreter;
  final List<String> labels;
  late List<int> _inputShape;
  late List<int> _outputShape;

  static Future<YamnetClassifier> load() async {
    final interpreter = await Interpreter.fromAsset(modelAsset);
    final labels = parseClassMap(await rootBundle.loadString(labelsAsset));
    final c = YamnetClassifier._(interpreter, labels);
    c._prepareShapes();
    return c;
  }

  void _prepareShapes() {
    var inShape = _interpreter.getInputTensor(0).shape;
    if (inShape.isEmpty || inShape.last != inputSamples) {
      final target = inShape.length == 2 ? [1, inputSamples] : [inputSamples];
      _interpreter.resizeInputTensor(0, target);
      _interpreter.allocateTensors();
      inShape = _interpreter.getInputTensor(0).shape;
    }
    _inputShape = inShape;
    _outputShape = _interpreter.getOutputTensor(0).shape;
  }

  /// คำอธิบายรูปทรงโมเดล ใช้แสดงในโหมดทดสอบ
  String get shapeInfo => 'in $_inputShape → out $_outputShape';

  /// คืนคะแนนของทุกคลาส (ยาว 521)
  List<double> classify(Float32List waveform) {
    final Object input = _inputShape.length == 1 ? waveform : [waveform];
    final numClasses = _outputShape.last;

    if (_outputShape.length == 1) {
      final out = List<double>.filled(numClasses, 0.0);
      _interpreter.run(input, out);
      return out;
    }

    final frames = _outputShape.first;
    final out = List.generate(frames, (_) => List<double>.filled(numClasses, 0.0));
    _interpreter.run(input, out);
    if (frames == 1) return out.first;

    final merged = List<double>.filled(numClasses, 0.0);
    for (final f in out) {
      for (var i = 0; i < numClasses; i++) {
        if (f[i] > merged[i]) merged[i] = f[i];
      }
    }
    return merged;
  }

  void close() => _interpreter.close();
}
