import 'categories.dart';

enum Sensitivity { low, medium, high }

extension SensitivityX on Sensitivity {
  /// ตัวคูณ threshold: ความไวสูง = threshold ต่ำลง = เตือนบ่อยขึ้น
  double get multiplier => switch (this) {
        Sensitivity.low => 1.25,
        Sensitivity.medium => 1.0,
        Sensitivity.high => 0.75,
      };

  String get labelTh => switch (this) {
        Sensitivity.low => 'ต่ำ',
        Sensitivity.medium => 'ปานกลาง',
        Sensitivity.high => 'สูง',
      };
}

class Detection {
  const Detection({
    required this.categoryId,
    required this.confidence,
    required this.time,
    required this.topLabel,
  });

  final String categoryId;
  final double confidence;
  final DateTime time;

  /// label ของ YAMNet ที่ได้คะแนนสูงสุดในหมวดนี้ (ไว้ดูตอนทดสอบ)
  final String topLabel;

  SoundCategory get category => categoryById(categoryId);

  Map<String, dynamic> toJson() => {
        'c': categoryId,
        'p': confidence,
        't': time.millisecondsSinceEpoch,
        'l': topLabel,
      };

  factory Detection.fromJson(Map<String, dynamic> j) => Detection(
        categoryId: j['c'] as String,
        confidence: (j['p'] as num).toDouble(),
        time: DateTime.fromMillisecondsSinceEpoch(j['t'] as int),
        topLabel: (j['l'] as String?) ?? '',
      );
}

/// แปลงคะแนน 521 คลาสของ YAMNet เป็นการเตือนของ EarSight
///
/// กติกา:
/// - คะแนนของหมวด = คะแนนสูงสุดของ label ในหมวดนั้น
/// - เสียงอันตรายเตือนทันทีตั้งแต่หน้าต่างแรกที่เกิน threshold (เร็วสำคัญกว่า)
/// - เสียงอื่นต้องเกิน threshold 2 หน้าต่างติดกัน (ลดการเตือนผิด)
/// - เสียงเดิมจะไม่เตือนซ้ำภายใน cooldown
class DetectionEngine {
  DetectionEngine(
    List<String> labels, {
    List<SoundCategory> categories = kCategories,
    Set<String>? enabled,
    this.sensitivity = Sensitivity.medium,
  })  : _categories = categories,
        _labels = labels,
        enabled = enabled ?? categories.map((c) => c.id).toSet() {
    for (final c in categories) {
      final idx = <int>[];
      for (final name in c.yamnetLabels) {
        final i = labels.indexOf(name);
        if (i >= 0) {
          idx.add(i);
        } else {
          missingLabels.add(name);
        }
      }
      _indices[c.id] = idx;
    }
  }

  final List<SoundCategory> _categories;
  final List<String> _labels;
  final Map<String, List<int>> _indices = {};
  final Map<String, DateTime> _lastFired = {};
  final Map<String, int> _streak = {};

  /// label ที่ตั้งไว้ใน categories แต่หาไม่เจอในโมเดล (ควรว่างเสมอ)
  final List<String> missingLabels = [];

  Set<String> enabled;
  Sensitivity sensitivity;

  double thresholdFor(SoundCategory c) =>
      (c.baseThreshold * sensitivity.multiplier).clamp(0.05, 0.95);

  /// ประมวลผลคะแนนหนึ่งหน้าต่าง คืนรายการเตือน เรียงจากสำคัญที่สุด
  List<Detection> process(List<double> scores, DateTime now) {
    final results = <Detection>[];
    for (final c in _categories) {
      if (!enabled.contains(c.id)) {
        _streak[c.id] = 0;
        continue;
      }
      var best = 0.0;
      var bestIdx = -1;
      for (final i in _indices[c.id]!) {
        if (i < scores.length && scores[i] > best) {
          best = scores[i];
          bestIdx = i;
        }
      }
      final streak = best >= thresholdFor(c) ? (_streak[c.id] ?? 0) + 1 : 0;
      _streak[c.id] = streak;

      final needed = c.level == AlertLevel.danger ? 1 : 2;
      if (streak < needed) continue;

      final last = _lastFired[c.id];
      if (last != null && now.difference(last) < c.cooldown) continue;

      _lastFired[c.id] = now;
      results.add(Detection(
        categoryId: c.id,
        confidence: best,
        time: now,
        topLabel: bestIdx >= 0 ? _labels[bestIdx] : '',
      ));
    }
    results.sort((a, b) {
      final byLevel = a.category.level.index.compareTo(b.category.level.index);
      return byLevel != 0 ? byLevel : b.confidence.compareTo(a.confidence);
    });
    return results;
  }

  void reset() {
    _streak.clear();
    _lastFired.clear();
  }
}
