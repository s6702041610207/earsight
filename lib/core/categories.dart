/// หมวดเสียงของ EarSight v1 และการจับคู่กับ label ของ YAMNet
///
/// ลำดับความสำคัญมาจากแบบสอบถามนักเรียนโรงเรียนเศรษฐเสถียรฯ (n = 27):
/// เคาะประตู 16, เรียกชื่อ/มีคนพูด 15, ไฟไหม้ 11, ไซเรน 11, รถ 10, กริ่ง 7
///
/// ไฟล์นี้ไม่ import Flutter เพื่อให้ทดสอบด้วย unit test ได้ง่าย
library;

/// ระดับการเตือน ("Alert Grammar") — กำหนดรูปแบบการสั่นและการแสดงผล
enum AlertLevel {
  /// อันตราย: สั่นแรงยาวต่อเนื่อง จอกะพริบ ต้องแตะปิดเอง
  danger,

  /// ต้องสนใจ: สั่น 2 ครั้ง ปิดเองอัตโนมัติ
  attention,

  /// แจ้งให้ทราบ: สั่นเบา 1 ครั้ง
  info,
}

class SoundCategory {
  const SoundCategory({
    required this.id,
    required this.nameTh,
    required this.levelTextTh,
    required this.level,
    required this.yamnetLabels,
    required this.baseThreshold,
    required this.cooldown,
  });

  final String id;
  final String nameTh;

  /// ข้อความรองใต้ชื่อเสียงบนหน้าจอเตือน
  final String levelTextTh;
  final AlertLevel level;

  /// display_name ใน yamnet_class_map.csv (ต้องตรงตัวอักษรทุกตัว)
  final List<String> yamnetLabels;

  /// คะแนนขั้นต่ำ (0-1) ที่ความไวระดับ "ปานกลาง"
  final double baseThreshold;

  /// เวลาขั้นต่ำก่อนเตือนเสียงเดิมซ้ำ
  final Duration cooldown;
}

const List<SoundCategory> kCategories = [
  SoundCategory(
    id: 'fire_alarm',
    nameTh: 'สัญญาณไฟไหม้',
    levelTextTh: 'อันตราย! ออกจากอาคาร',
    level: AlertLevel.danger,
    yamnetLabels: ['Smoke detector, smoke alarm', 'Fire alarm', 'Alarm'],
    baseThreshold: 0.30,
    cooldown: Duration(seconds: 5),
  ),
  SoundCategory(
    id: 'siren',
    nameTh: 'เสียงไซเรน',
    levelTextTh: 'อันตราย! มีรถฉุกเฉินหรือเตือนภัย',
    level: AlertLevel.danger,
    yamnetLabels: [
      'Siren',
      'Civil defense siren',
      'Emergency vehicle',
      'Police car (siren)',
      'Ambulance (siren)',
      'Fire engine, fire truck (siren)',
    ],
    baseThreshold: 0.30,
    cooldown: Duration(seconds: 5),
  ),
  SoundCategory(
    id: 'vehicle_horn',
    nameTh: 'แตรรถ',
    levelTextTh: 'ระวัง! มีรถอยู่ใกล้',
    level: AlertLevel.danger,
    yamnetLabels: ['Vehicle horn, car horn, honking', 'Air horn, truck horn'],
    baseThreshold: 0.30,
    cooldown: Duration(seconds: 5),
  ),
  SoundCategory(
    id: 'knock',
    nameTh: 'เคาะประตู',
    levelTextTh: 'มีคนมาที่ประตู',
    level: AlertLevel.attention,
    yamnetLabels: ['Knock', 'Door'],
    baseThreshold: 0.35,
    cooldown: Duration(seconds: 8),
  ),
  SoundCategory(
    id: 'doorbell',
    nameTh: 'กริ่ง / ออด',
    levelTextTh: 'มีคนกดกริ่ง',
    level: AlertLevel.attention,
    yamnetLabels: ['Doorbell', 'Ding-dong'],
    baseThreshold: 0.35,
    cooldown: Duration(seconds: 8),
  ),
  SoundCategory(
    id: 'speech',
    nameTh: 'มีคนพูดใกล้ๆ',
    levelTextTh: 'อาจมีคนเรียกคุณ',
    level: AlertLevel.info,
    yamnetLabels: [
      'Speech',
      'Child speech, kid speaking',
      'Conversation',
      'Shout',
      'Yell',
    ],
    baseThreshold: 0.60,
    cooldown: Duration(seconds: 20),
  ),
];

SoundCategory categoryById(String id) =>
    kCategories.firstWhere((c) => c.id == id);

/// อ่าน yamnet_class_map.csv (index,mid,display_name) → รายชื่อ label ตาม index
List<String> parseClassMap(String csv) {
  final labels = <String>[];
  final lines = csv.split(RegExp(r'\r?\n'));
  for (var i = 1; i < lines.length; i++) {
    final line = lines[i].trim();
    if (line.isEmpty) continue;
    final fields = _splitCsvLine(line);
    if (fields.length >= 3) labels.add(fields[2]);
  }
  return labels;
}

List<String> _splitCsvLine(String line) {
  final out = <String>[];
  final buf = StringBuffer();
  var inQuotes = false;
  for (var i = 0; i < line.length; i++) {
    final ch = line[i];
    if (ch == '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
        buf.write('"');
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (ch == ',' && !inQuotes) {
      out.add(buf.toString());
      buf.clear();
    } else {
      buf.write(ch);
    }
  }
  out.add(buf.toString());
  return out;
}
