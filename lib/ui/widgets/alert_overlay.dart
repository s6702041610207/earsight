import 'package:flutter/material.dart';

import '../../core/categories.dart';
import '../../core/detection_engine.dart';
import '../category_style.dart';

/// หน้าจอเตือนเต็มจอ: ชื่อเสียงตัวใหญ่ + ไอคอน + สีประจำเสียง
/// เสียงอันตรายจะกะพริบจนกว่าผู้ใช้จะแตะปิด
class AlertOverlay extends StatefulWidget {
  const AlertOverlay({super.key, required this.detection, required this.onDismiss});

  final Detection detection;
  final VoidCallback onDismiss;

  @override
  State<AlertOverlay> createState() => _AlertOverlayState();
}

class _AlertOverlayState extends State<AlertOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  bool get _isDanger => widget.detection.category.level == AlertLevel.danger;

  @override
  void initState() {
    super.initState();
    if (_isDanger) _flash.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant AlertOverlay old) {
    super.didUpdateWidget(old);
    if (_isDanger && !_flash.isAnimating) {
      _flash.repeat(reverse: true);
    } else if (!_isDanger && _flash.isAnimating) {
      _flash
        ..stop()
        ..value = 0;
    }
  }

  @override
  void dispose() {
    _flash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detection;
    final c = d.category;
    final style = CategoryStyle.of(c.id);
    final dark = Color.lerp(style.color, Colors.black, 0.55)!;

    return Semantics(
      liveRegion: true,
      label: 'แจ้งเตือน ${c.nameTh} ${c.levelTextTh}',
      child: GestureDetector(
        onTap: widget.onDismiss,
        child: AnimatedBuilder(
          animation: _flash,
          builder: (context, child) => Container(
            color: Color.lerp(style.color, dark, _flash.value),
            child: child,
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      levelNameTh(c.level),
                      style: const TextStyle(
                          color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Spacer(),
                  Icon(style.icon, size: 160, color: Colors.white),
                  const SizedBox(height: 24),
                  Text(
                    c.nameTh,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 48, fontWeight: FontWeight.w800, height: 1.1),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    c.levelTextTh,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    formatTime(d.time),
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 18),
                  ),
                  const Spacer(),
                  Text(
                    'แตะที่ใดก็ได้เพื่อปิด',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 20),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
