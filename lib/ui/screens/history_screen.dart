import 'package:flutter/material.dart';

import '../../services/app_store.dart';
import '../category_style.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.store});
  final AppStore store;

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ลบประวัติทั้งหมด?'),
        content: const Text('ประวัติเสียงที่ตรวจพบในเครื่องนี้จะถูกลบ'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ยกเลิก')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ลบ')),
        ],
      ),
    );
    if (ok == true) await store.clearHistory();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: const Text('ประวัติเสียง'),
          actions: [
            if (store.history.isNotEmpty)
              IconButton(
                tooltip: 'ลบประวัติ',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => _confirmClear(context),
              ),
          ],
        ),
        body: store.history.isEmpty
            ? const Center(
                child: Text('ยังไม่มีเสียงที่ตรวจพบ', style: TextStyle(fontSize: 18)))
            : ListView.separated(
                itemCount: store.history.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final d = store.history[i];
                  final s = CategoryStyle.of(d.categoryId);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: s.color,
                      child: Icon(s.icon, color: Colors.white),
                    ),
                    title: Text(d.category.nameTh,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
                    subtitle: Text(formatTime(d.time, withDate: true)),
                    trailing: Text('${(d.confidence * 100).round()}%',
                        style: const TextStyle(fontSize: 16)),
                  );
                },
              ),
      ),
    );
  }
}
