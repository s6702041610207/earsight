import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/categories.dart';
import '../core/detection_engine.dart';

/// การตั้งค่าและประวัติ เก็บในเครื่องเท่านั้น (SharedPreferences)
/// ประวัติเก็บแค่ชื่อเสียง เวลา และความมั่นใจ — ไม่มีไฟล์เสียง
class AppStore extends ChangeNotifier {
  AppStore._(this._prefs);

  static const _kEnabled = 'enabled_categories';
  static const _kSensitivity = 'sensitivity';
  static const _kVibrate = 'vibrate';
  static const _kDebug = 'debug';
  static const _kHistory = 'history';
  static const maxHistory = 200;

  final SharedPreferences _prefs;

  late Set<String> enabled;
  late Sensitivity sensitivity;
  late bool vibrate;
  late bool debug;
  late List<Detection> history;

  static Future<AppStore> load() async {
    final s = AppStore._(await SharedPreferences.getInstance());
    s.enabled = (s._prefs.getStringList(_kEnabled) ??
            kCategories.map((c) => c.id).toList())
        .toSet();
    s.sensitivity = Sensitivity.values[
        (s._prefs.getInt(_kSensitivity) ?? Sensitivity.medium.index)
            .clamp(0, Sensitivity.values.length - 1)];
    s.vibrate = s._prefs.getBool(_kVibrate) ?? true;
    s.debug = s._prefs.getBool(_kDebug) ?? false;
    s.history = [];
    for (final raw in s._prefs.getStringList(_kHistory) ?? const <String>[]) {
      try {
        s.history.add(Detection.fromJson(jsonDecode(raw) as Map<String, dynamic>));
      } catch (_) {
        // ข้ามรายการที่เสีย
      }
    }
    return s;
  }

  Future<void> setEnabled(String id, bool on) async {
    on ? enabled.add(id) : enabled.remove(id);
    await _prefs.setStringList(_kEnabled, enabled.toList());
    notifyListeners();
  }

  Future<void> setSensitivity(Sensitivity v) async {
    sensitivity = v;
    await _prefs.setInt(_kSensitivity, v.index);
    notifyListeners();
  }

  Future<void> setVibrate(bool v) async {
    vibrate = v;
    await _prefs.setBool(_kVibrate, v);
    notifyListeners();
  }

  Future<void> setDebug(bool v) async {
    debug = v;
    await _prefs.setBool(_kDebug, v);
    notifyListeners();
  }

  Future<void> addHistory(Detection d) async {
    history.insert(0, d);
    if (history.length > maxHistory) history.removeRange(maxHistory, history.length);
    await _saveHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    history.clear();
    await _saveHistory();
    notifyListeners();
  }

  Future<void> _saveHistory() => _prefs.setStringList(
      _kHistory, history.map((d) => jsonEncode(d.toJson())).toList());
}
