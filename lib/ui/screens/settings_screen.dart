import 'package:flutter/material.dart';

import '../../core/categories.dart';
import '../../core/detection_engine.dart';
import '../../services/app_store.dart';
import '../../services/listen_controller.dart';
import '../category_style.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store, required this.controller});

  final AppStore store;
  final ListenController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: const Text('ตั้งค่า')),
        body: ListView(
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            const _Header('เสียงที่ต้องการให้เตือน'),
            for (final c in kCategories)
              SwitchListTile(
                value: store.enabled.contains(c.id),
                onChanged: (v) => store.setEnabled(c.id, v),
                secondary: IconButton(
                  tooltip: 'ดูตัวอย่างการเตือน',
                  icon: CircleAvatar(
                    backgroundColor: CategoryStyle.of(c.id).color,
                    child: Icon(CategoryStyle.of(c.id).icon, color: Colors.white),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                    controller.previewAlert(c.id);
                  },
                ),
                title: Text(c.nameTh, style: const TextStyle(fontSize: 18)),
                subtitle: Text(levelNameTh(c.level)),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text('แตะที่ไอคอนเพื่อดูตัวอย่างหน้าจอเตือน'),
            ),
            const Divider(),
            const _Header('ความไวในการจับเสียง'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SegmentedButton<Sensitivity>(
                segments: [
                  for (final s in Sensitivity.values)
                    ButtonSegment(value: s, label: Text(s.labelTh)),
                ],
                selected: {store.sensitivity},
                onSelectionChanged: (v) => store.setSensitivity(v.first),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('ความไวสูง = เตือนบ่อยขึ้น แต่อาจเตือนผิดมากขึ้น'),
            ),
            const Divider(),
            SwitchListTile(
              value: store.vibrate,
              onChanged: store.setVibrate,
              secondary: const Icon(Icons.vibration),
              title: const Text('สั่นเมื่อเตือน', style: TextStyle(fontSize: 18)),
              subtitle: const Text('เสียงอันตรายสั่นยาวและแรง เสียงทั่วไปสั่นสั้น'),
            ),
            SwitchListTile(
              value: store.debug,
              onChanged: store.setDebug,
              secondary: const Icon(Icons.science_outlined),
              title: const Text('โหมดทดสอบ (สำหรับทีมพัฒนา)'),
              subtitle: const Text('แสดงชื่อเสียงที่โมเดลได้ยินบนหน้าหลัก'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: Theme.of(context).colorScheme.primary)),
      );
}
