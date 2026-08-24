import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin, fully offline persistence layer on top of SharedPreferences.
class Storage {
  Storage(this._prefs);

  final SharedPreferences _prefs;

  static const _kOnboarded = 'onboarded';
  static const _kTopics = 'topics';
  static const _kSavedBolts = 'saved_bolts';
  static const _kSkipped = 'skipped_ids';
  static const _kSeen = 'seen_ids';
  static const _kMyBolts = 'my_bolts';
  static const _kMyPosts = 'my_posts';
  static const _kLikedPosts = 'liked_posts';
  static const _kDailyPrefix = 'daily_';
  static const _kDailyClaimed = 'daily_claimed';
  static const _kStreak = 'streak';
  static const _kLastOpen = 'last_open';
  static const _kVisitStreak = 'visit_streak';
  static const _kLastVisitDay = 'last_visit_day';
  static const _kTotalSwipes = 'total_swipes';
  static const _kHaptics = 'haptics';
  static const _kMotion = 'motion';
  static const _kNickname = 'nickname';

  // ---------------------------------------------------------- sleep ritual
  static const _kEveningEntries = 'evening_entries';
  static const _kDreamEntries = 'dream_entries';
  static const _kLastMorningDate = 'last_morning_date';
  static const _kMorningChargeDays = 'morning_charge_days';
  static const _kMorningChargeEnabled = 'morning_charge_enabled';
  static const _kEveningDischargeEnabled = 'evening_discharge_enabled';
  static const _kEveningReminderMinutes = 'evening_reminder_minutes';

  static Future<Storage> open() async =>
      Storage(await SharedPreferences.getInstance());

  bool get onboarded => _prefs.getBool(_kOnboarded) ?? false;
  Future<void> setOnboarded(bool value) => _prefs.setBool(_kOnboarded, value);

  List<String> get topics => _prefs.getStringList(_kTopics) ?? const [];
  Future<void> setTopics(List<String> value) => _prefs.setStringList(_kTopics, value);

  List<Map<String, dynamic>> get savedBolts => _readList(_kSavedBolts);
  Future<void> setSavedBolts(List<Map<String, dynamic>> value) =>
      _writeList(_kSavedBolts, value);

  List<Map<String, dynamic>> get myBolts => _readList(_kMyBolts);
  Future<void> setMyBolts(List<Map<String, dynamic>> value) =>
      _writeList(_kMyBolts, value);

  List<Map<String, dynamic>> get myPosts => _readList(_kMyPosts);
  Future<void> setMyPosts(List<Map<String, dynamic>> value) =>
      _writeList(_kMyPosts, value);

  List<String> get skippedIds => _prefs.getStringList(_kSkipped) ?? const [];
  Future<void> setSkippedIds(List<String> value) =>
      _prefs.setStringList(_kSkipped, value);

  List<String> get seenIds => _prefs.getStringList(_kSeen) ?? const [];
  Future<void> setSeenIds(List<String> value) => _prefs.setStringList(_kSeen, value);

  List<String> get likedPosts => _prefs.getStringList(_kLikedPosts) ?? const [];
  Future<void> setLikedPosts(List<String> value) =>
      _prefs.setStringList(_kLikedPosts, value);

  String? dailyBoltId(String dayKey) => _prefs.getString('$_kDailyPrefix$dayKey');
  Future<void> setDailyBoltId(String dayKey, String id) =>
      _prefs.setString('$_kDailyPrefix$dayKey', id);

  String? get dailyClaimedDay => _prefs.getString(_kDailyClaimed);
  Future<void> setDailyClaimedDay(String value) =>
      _prefs.setString(_kDailyClaimed, value);

  int get streak => _prefs.getInt(_kStreak) ?? 0;
  Future<void> setStreak(int value) => _prefs.setInt(_kStreak, value);

  String? get lastOpenDay => _prefs.getString(_kLastOpen);
  Future<void> setLastOpenDay(String value) => _prefs.setString(_kLastOpen, value);

  /// Passive "days-in-a-row-opened" streak. Distinct from [streak], which is
  /// gated on the user tapping "Unleash today's bolt" — this one advances
  /// automatically on the first bootstrap of every new calendar day.
  int get visitStreak => _prefs.getInt(_kVisitStreak) ?? 0;
  Future<void> setVisitStreak(int value) => _prefs.setInt(_kVisitStreak, value);

  String? get lastVisitDay => _prefs.getString(_kLastVisitDay);
  Future<void> setLastVisitDay(String value) =>
      _prefs.setString(_kLastVisitDay, value);

  int get totalSwipes => _prefs.getInt(_kTotalSwipes) ?? 0;
  Future<void> setTotalSwipes(int value) => _prefs.setInt(_kTotalSwipes, value);

  bool get haptics => _prefs.getBool(_kHaptics) ?? true;
  Future<void> setHaptics(bool value) => _prefs.setBool(_kHaptics, value);

  bool get motion => _prefs.getBool(_kMotion) ?? true;
  Future<void> setMotion(bool value) => _prefs.setBool(_kMotion, value);

  String get nickname => _prefs.getString(_kNickname) ?? 'You';
  Future<void> setNickname(String value) => _prefs.setString(_kNickname, value);

  // ---------------------------------------------------------- sleep ritual

  List<Map<String, dynamic>> get eveningEntries => _readList(_kEveningEntries);
  Future<void> setEveningEntries(List<Map<String, dynamic>> value) =>
      _writeList(_kEveningEntries, value);

  List<Map<String, dynamic>> get dreamEntries => _readList(_kDreamEntries);
  Future<void> setDreamEntries(List<Map<String, dynamic>> value) =>
      _writeList(_kDreamEntries, value);

  String? get lastMorningDate => _prefs.getString(_kLastMorningDate);
  Future<void> setLastMorningDate(String value) =>
      _prefs.setString(_kLastMorningDate, value);

  /// Every calendar day (yyyy-MM-dd) on which a Morning Charge was
  /// completed. This is the source of truth the sleep streak is recomputed
  /// from, so a gap while the app was untouched always shows correctly.
  List<String> get morningChargeDays =>
      _prefs.getStringList(_kMorningChargeDays) ?? const [];
  Future<void> setMorningChargeDays(List<String> value) =>
      _prefs.setStringList(_kMorningChargeDays, value);

  bool get morningChargeEnabled => _prefs.getBool(_kMorningChargeEnabled) ?? true;
  Future<void> setMorningChargeEnabled(bool value) =>
      _prefs.setBool(_kMorningChargeEnabled, value);

  bool get eveningDischargeEnabled =>
      _prefs.getBool(_kEveningDischargeEnabled) ?? true;
  Future<void> setEveningDischargeEnabled(bool value) =>
      _prefs.setBool(_kEveningDischargeEnabled, value);

  /// Minutes after midnight; defaults to 21:00.
  int get eveningReminderMinutes =>
      _prefs.getInt(_kEveningReminderMinutes) ?? 21 * 60;
  Future<void> setEveningReminderMinutes(int value) =>
      _prefs.setInt(_kEveningReminderMinutes, value);

  Future<void> wipe() async {
    for (final key in _prefs.getKeys().toList()) {
      await _prefs.remove(key);
    }
  }

  List<Map<String, dynamic>> _readList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeList(String key, List<Map<String, dynamic>> value) =>
      _prefs.setString(key, jsonEncode(value));
}
