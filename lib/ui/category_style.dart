import 'package:flutter/material.dart';

import '../core/categories.dart';

/// สีและไอคอนของแต่ละเสียง (ผู้ตอบแบบสอบถามอยากได้สีต่างกันตามประเภทเสียง)
/// เสียงอันตรายใช้โทนแดง/ส้ม เสียงทั่วไปใช้โทนเย็น
class CategoryStyle {
  const CategoryStyle(this.icon, this.color);
  final IconData icon;
  final Color color;

  static const _styles = <String, CategoryStyle>{
    'fire_alarm': CategoryStyle(Icons.local_fire_department, Color(0xFFD84315)),
    'siren': CategoryStyle(Icons.emergency, Color(0xFFC62828)),
    'vehicle_horn': CategoryStyle(Icons.directions_car, Color(0xFFAD1457)),
    'knock': CategoryStyle(Icons.door_front_door, Color(0xFF1565C0)),
    'doorbell': CategoryStyle(Icons.notifications_active, Color(0xFF6A1B9A)),
    'speech': CategoryStyle(Icons.record_voice_over, Color(0xFF2E7D32)),
  };

  static CategoryStyle of(String id) =>
      _styles[id] ?? const CategoryStyle(Icons.hearing, Colors.blueGrey);
}

String levelNameTh(AlertLevel l) => switch (l) {
      AlertLevel.danger => 'อันตราย',
      AlertLevel.attention => 'ต้องสนใจ',
      AlertLevel.info => 'แจ้งให้ทราบ',
    };

String formatTime(DateTime t, {bool withDate = false}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final time = '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  if (!withDate) return time;
  return '${two(t.day)}/${two(t.month)}/${t.year + 543}  $time';
}
