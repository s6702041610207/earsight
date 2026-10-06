import 'package:flutter/material.dart';

import '../../core/categories.dart';
import '../../services/app_store.dart';
import '../../services/listen_controller.dart';
import '../category_style.dart';
import '../widgets/alert_overlay.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.store, required this.controller});

  final AppStore store;
  final ListenController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([store, controller]),
      builder: (context, _) {
        final alert = controller.currentAlert;
        return Stack(
          children: [
            Scaffold(
              appBar: AppBar(
                title: const Text('EarSight', style: TextStyle(fontWeight: FontWeight.w800)),
                actions: [
                  IconButton(
                    tooltip: 'ประวัติเสียง',
                    icon: const Icon(Icons.history, size: 28),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => HistoryScreen(store: store))),
                  ),
                  IconButton(
                    tooltip: 'ตั้งค่า',
                    icon: const Icon(Icons.settings, size: 28),
                    onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => SettingsScreen(store: store, controller: controller))),
                  ),
                ],
              ),
              body: SafeArea(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _ListenButton(controller: controller),
                    const SizedBox(height: 16),
                    _StatusText(controller: controller),
                    if (controller.isListening) ...[
                      const SizedBox(height: 12),
                      _LevelBar(level: controller.level),
                    ],
                    if (store.debug && controller.isListening) ...[
                      const SizedBox(height: 8),
                      Text('ได้ยิน: ${controller.debugTop}\n${controller.debugShape}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                    const SizedBox(height: 20),
                    const _PrivacyCard(),
                    const SizedBox(height: 20),
                    Text('เสียงที่แอปเตือน', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    _Legend(store: store),
                    const SizedBox(height: 20),
                    _RecentList(store: store),
                  ],
                ),
              ),
            ),
            if (alert != null)
              Positioned.fill(
                child: Material(
                  type: MaterialType.transparency,
                  child: AlertOverlay(
                    key: ValueKey(alert.time.microsecondsSinceEpoch),
                    detection: alert,
                    onDismiss: controller.dismissAlert,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _ListenButton extends StatelessWidget {
  const _ListenButton({required this.controller});
  final ListenController controller;

  @override
  Widget build(BuildContext context) {
    final on = controller.isListening;
    final loading = controller.state == ListenState.loading;
    final color = on ? const Color(0xFF2E7D32) : Theme.of(context).colorScheme.primary;

    return Center(
      child: Semantics(
        button: true,
        label: on ? 'หยุดฟังเสียง' : 'เริ่มฟังเสียง',
        child: GestureDetector(
          onTap: loading ? null : controller.toggle,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: on ? 0.45 : 0.25),
                  blurRadius: on ? 40 : 16,
                  spreadRadius: on ? 8 : 0,
                ),
              ],
            ),
            child: loading
                ? const Center(child: CircularProgressIndicator(color: Colors.white))
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(on ? Icons.hearing : Icons.hearing_disabled,
                          size: 80, color: Colors.white),
                      const SizedBox(height: 8),
                      Text(on ? 'แตะเพื่อหยุด' : 'แตะเพื่อเริ่มฟัง',
                          style: const TextStyle(
                              color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _StatusText extends StatelessWidget {
  const _StatusText({required this.controller});
  final ListenController controller;

  @override
  Widget build(BuildContext context) {
    final (text, color) = switch (controller.state) {
      ListenState.listening => ('กำลังฟังเสียงรอบตัว', const Color(0xFF2E7D32)),
      ListenState.loading => ('กำลังเตรียมโมเดล...', Colors.grey.shade700),
      ListenState.error => (controller.errorMessage ?? 'เกิดข้อผิดพลาด', Colors.red.shade700),
      ListenState.idle => ('ยังไม่ได้ฟังเสียง', Colors.grey.shade700),
    };
    return Text(text,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color));
  }
}

class _LevelBar extends StatelessWidget {
  const _LevelBar({required this.level});
  final double level;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'ระดับเสียงรอบตัว',
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: LinearProgressIndicator(
          value: level,
          minHeight: 14,
          backgroundColor: Colors.grey.shade300,
          color: Color.lerp(Colors.green, Colors.red, level),
        ),
      ),
    );
  }
}

class _PrivacyCard extends StatelessWidget {
  const _PrivacyCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: const Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'แอปฟังเสียงเฉพาะตอนที่คุณกดเริ่ม ประมวลผลในโทรศัพท์เครื่องนี้เท่านั้น '
                'ไม่บันทึกเสียง และไม่ส่งเสียงขึ้นอินเทอร์เน็ต',
                style: TextStyle(fontSize: 16, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in kCategories)
          if (store.enabled.contains(c.id))
            Chip(
              avatar: Icon(CategoryStyle.of(c.id).icon, color: Colors.white, size: 20),
              label: Text(c.nameTh,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              backgroundColor: CategoryStyle.of(c.id).color,
              side: BorderSide.none,
            ),
      ],
    );
  }
}

class _RecentList extends StatelessWidget {
  const _RecentList({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final recent = store.history.take(5).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ล่าสุด', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (recent.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('ยังไม่มีเสียงที่ตรวจพบ', style: TextStyle(fontSize: 16)),
          ),
        for (final d in recent)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: CategoryStyle.of(d.categoryId).color,
              child: Icon(CategoryStyle.of(d.categoryId).icon, color: Colors.white),
            ),
            title: Text(d.category.nameTh, style: const TextStyle(fontSize: 18)),
            trailing: Text(formatTime(d.time), style: const TextStyle(fontSize: 16)),
          ),
      ],
    );
  }
}
