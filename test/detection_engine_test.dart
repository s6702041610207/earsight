import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:earsight/core/categories.dart';
import 'package:earsight/core/detection_engine.dart';

void main() {
  late List<String> labels;

  setUpAll(() {
    labels = parseClassMap(File('assets/models/yamnet_class_map.csv').readAsStringSync());
  });

  List<double> scoresWith(Map<String, double> byLabel) {
    final s = List<double>.filled(labels.length, 0.0);
    byLabel.forEach((name, v) => s[labels.indexOf(name)] = v);
    return s;
  }

  test('class map has 521 YAMNet labels', () {
    expect(labels.length, 521);
    expect(labels.first, 'Speech');
    expect(labels[302], 'Vehicle horn, car horn, honking');
  });

  test('every category label exists in YAMNet', () {
    final engine = DetectionEngine(labels);
    expect(engine.missingLabels, isEmpty);
  });

  test('danger fires on first window', () {
    final engine = DetectionEngine(labels);
    final out = engine.process(scoresWith({'Fire alarm': 0.8}), DateTime(2026));
    expect(out.single.categoryId, 'fire_alarm');
  });

  test('attention needs two consecutive windows', () {
    final engine = DetectionEngine(labels);
    final t = DateTime(2026);
    expect(engine.process(scoresWith({'Knock': 0.7}), t), isEmpty);
    final out = engine.process(scoresWith({'Knock': 0.7}), t.add(const Duration(milliseconds: 500)));
    expect(out.single.categoryId, 'knock');
  });

  test('cooldown blocks repeat alerts', () {
    final engine = DetectionEngine(labels);
    final t = DateTime(2026);
    final s = scoresWith({'Siren': 0.9});
    expect(engine.process(s, t), hasLength(1));
    expect(engine.process(s, t.add(const Duration(seconds: 2))), isEmpty);
    expect(engine.process(s, t.add(const Duration(seconds: 6))), hasLength(1));
  });

  test('disabled category never fires', () {
    final engine = DetectionEngine(labels, enabled: {'knock'});
    expect(engine.process(scoresWith({'Siren': 0.9}), DateTime(2026)), isEmpty);
  });

  test('sensitivity changes threshold', () {
    final low = DetectionEngine(labels, sensitivity: Sensitivity.low);
    final high = DetectionEngine(labels, sensitivity: Sensitivity.high);
    final s = scoresWith({'Vehicle horn, car horn, honking': 0.3});
    expect(low.process(s, DateTime(2026)), isEmpty);
    expect(high.process(s, DateTime(2026)), hasLength(1));
  });

  test('danger sorted before others', () {
    final engine = DetectionEngine(labels);
    final t = DateTime(2026);
    final s = scoresWith({'Doorbell': 0.9, 'Siren': 0.5});
    engine.process(s, t);
    final out = engine.process(s, t.add(const Duration(seconds: 6)));
    expect(out.first.categoryId, 'siren');
  });
}
