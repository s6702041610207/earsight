import 'package:vibration/vibration.dart';

import '../core/categories.dart';

/// รูปแบบการสั่นตาม Alert Grammar
/// pattern = [รอ, สั่น, หยุด, สั่น, ...] หน่วยมิลลิวินาที
class Haptics {
  bool? _hasVibrator;
  bool? _hasAmplitude;

  static const _patterns = <AlertLevel, List<int>>{
    // อันตราย: ยาว-แรง 3 ครั้ง แล้วยาวพิเศษ 1 ครั้ง
    AlertLevel.danger: [0, 500, 150, 500, 150, 500, 150, 1000],
    // ต้องสนใจ: สั้น 2 ครั้ง (เหมือนเคาะประตู)
    AlertLevel.attention: [0, 200, 150, 200],
    // แจ้งให้ทราบ: สั้นเบา 1 ครั้ง
    AlertLevel.info: [0, 150],
  };

  static const _intensities = <AlertLevel, List<int>>{
    AlertLevel.danger: [0, 255, 0, 255, 0, 255, 0, 255],
    AlertLevel.attention: [0, 180, 0, 180],
    AlertLevel.info: [0, 90],
  };

  Future<void> play(AlertLevel level) async {
    _hasVibrator ??= await Vibration.hasVibrator() == true;
    if (_hasVibrator != true) return;
    _hasAmplitude ??= await Vibration.hasAmplitudeControl() == true;
    await Vibration.vibrate(
      pattern: _patterns[level]!,
      intensities: _hasAmplitude == true ? _intensities[level]! : const [],
    );
  }

  Future<void> stop() => Vibration.cancel();
}
