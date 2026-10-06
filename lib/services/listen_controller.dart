import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../core/categories.dart';
import '../core/detection_engine.dart';
import 'app_store.dart';
import 'audio_windows.dart' if (dart.library.js_interop) 'audio_windows_stub.dart';
import 'haptics.dart';
import 'yamnet_classifier.dart' if (dart.library.js_interop) 'yamnet_classifier_stub.dart';

enum ListenState { idle, loading, listening, error }

/// ตัวกลางของแอป: ไมค์ → YAMNet → DetectionEngine → การเตือน
class ListenController extends ChangeNotifier {
  ListenController(this.store) {
    store.addListener(_syncSettings);
  }

  final AppStore store;
  final AudioWindowStream _audio = AudioWindowStream();
  final Haptics _haptics = Haptics();

  YamnetClassifier? _classifier;
  DetectionEngine? _engine;
  StreamSubscription<Float32List>? _windowSub;
  StreamSubscription<double>? _levelSub;
  Timer? _autoDismiss;
  Timer? _previewLevel;
  bool _busy = false;

  /// true เมื่อรันเป็นหน้าพรีวิวบนเว็บ (ไม่มี AI / ไมค์จริง)
  bool get isWebPreview => kIsWeb;

  ListenState state = ListenState.idle;
  String? errorMessage;
  double level = 0;

  /// การเตือนที่กำลังแสดงเต็มจอ (null = ไม่มี)
  Detection? currentAlert;

  /// สำหรับโหมดทดสอบ: label อันดับ 1 ของหน้าต่างล่าสุด
  String debugTop = '';
  String get debugShape => _classifier?.shapeInfo ?? '';

  bool get isListening => state == ListenState.listening;

  Future<void> toggle() => isListening ? stop() : start();

  Future<void> start() async {
    if (state == ListenState.loading || isListening) return;
    if (isWebPreview) {
      // พรีวิวบนเว็บ: แสดงสถานะ "กำลังฟัง" พร้อมแถบระดับเสียงจำลอง
      final rnd = math.Random();
      _previewLevel = Timer.periodic(const Duration(milliseconds: 150), (_) {
        level = 0.15 + rnd.nextDouble() * 0.35;
        notifyListeners();
      });
      _setState(ListenState.listening);
      return;
    }
    _setState(ListenState.loading);
    try {
      _classifier ??= await YamnetClassifier.load();
      _engine ??= DetectionEngine(_classifier!.labels);
      if (_engine!.missingLabels.isNotEmpty) {
        debugPrint('EarSight: labels not found ${_engine!.missingLabels}');
      }
      _syncSettings();
      _engine!.reset();

      final ok = await _audio.start();
      if (!ok) {
        _fail('ต้องอนุญาตให้ใช้ไมโครโฟนก่อน\nไปที่ ตั้งค่า > แอป > EarSight > สิทธิ์');
        return;
      }
      _windowSub = _audio.windows.listen(_onWindow);
      _levelSub = _audio.levels.listen((v) {
        level = v;
        notifyListeners();
      });
      await WakelockPlus.enable();
      _setState(ListenState.listening);
    } catch (e) {
      _fail('เริ่มฟังเสียงไม่สำเร็จ\n$e');
    }
  }

  Future<void> stop() async {
    _previewLevel?.cancel();
    _previewLevel = null;
    if (isWebPreview) {
      level = 0;
      _setState(ListenState.idle);
      return;
    }
    await _windowSub?.cancel();
    await _levelSub?.cancel();
    _windowSub = null;
    _levelSub = null;
    await _audio.stop();
    await WakelockPlus.disable();
    level = 0;
    _setState(ListenState.idle);
  }

  void _onWindow(Float32List window) {
    // ถ้ารอบก่อนยังไม่เสร็จ ข้ามหน้าต่างนี้ เพื่อไม่ให้งานค้างสะสม
    if (_busy || _classifier == null || _engine == null) return;
    _busy = true;
    try {
      final scores = _classifier!.classify(window);
      if (store.debug) _updateDebugTop(scores);
      final found = _engine!.process(scores, DateTime.now());
      for (final d in found) {
        store.addHistory(d);
      }
      if (found.isNotEmpty) _showAlert(found.first);
    } catch (e) {
      debugPrint('EarSight classify error: $e');
    } finally {
      _busy = false;
    }
  }

  void _updateDebugTop(List<double> scores) {
    var best = 0;
    for (var i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    final labels = _classifier!.labels;
    final name = best < labels.length ? labels[best] : '#$best';
    debugTop = '$name ${(scores[best] * 100).toStringAsFixed(0)}%';
    notifyListeners();
  }

  /// แสดงการเตือน — เสียงอันตรายจะไม่ถูกแทนที่ด้วยเสียงที่สำคัญน้อยกว่า
  void _showAlert(Detection d) {
    final cur = currentAlert;
    if (cur != null &&
        cur.category.level == AlertLevel.danger &&
        d.category.level != AlertLevel.danger) {
      return;
    }
    currentAlert = d;
    if (store.vibrate) _haptics.play(d.category.level);

    _autoDismiss?.cancel();
    if (d.category.level != AlertLevel.danger) {
      final secs = d.category.level == AlertLevel.info ? 5 : 10;
      _autoDismiss = Timer(Duration(seconds: secs), dismissAlert);
    }
    notifyListeners();
  }

  /// ใช้ในหน้าตั้งค่า เพื่อให้ผู้ใช้ดูหน้าตาการเตือนแต่ละแบบโดยไม่ต้องมีเสียงจริง
  void previewAlert(String categoryId, {bool addToHistory = false}) {
    final d = Detection(
      categoryId: categoryId,
      confidence: 1,
      time: DateTime.now(),
      topLabel: 'ทดสอบ',
    );
    if (addToHistory) store.addHistory(d);
    _showAlert(d);
  }

  void dismissAlert() {
    _autoDismiss?.cancel();
    _haptics.stop();
    currentAlert = null;
    notifyListeners();
  }

  void _syncSettings() {
    final e = _engine;
    if (e == null) return;
    e.enabled = {...store.enabled};
    e.sensitivity = store.sensitivity;
  }

  void _fail(String msg) {
    errorMessage = msg;
    _setState(ListenState.error);
    _audio.stop();
  }

  void _setState(ListenState s) {
    state = s;
    if (s != ListenState.error) errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    store.removeListener(_syncSettings);
    _autoDismiss?.cancel();
    _previewLevel?.cancel();
    _windowSub?.cancel();
    _levelSub?.cancel();
    _audio.dispose();
    _classifier?.close();
    super.dispose();
  }
}
