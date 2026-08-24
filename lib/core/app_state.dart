import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'date_keys.dart';
import 'models.dart';
import 'sleep_utils.dart';
import 'storage.dart';

typedef ProgressReport = void Function(double value, String label);

/// Single source of truth for the whole app. Everything lives on the device,
/// so the app is fully usable with the radio switched off.
class AppState extends ChangeNotifier {
  AppState._(this._storage, this._mediaDir);

  final Storage _storage;
  final Directory _mediaDir;

  final List<Bolt> _library = [];
  final List<CommunityPost> _seedFeed = [];
  final List<CommunityPost> _myPosts = [];
  final List<Bolt> _saved = [];
  final List<Bolt> _myBolts = [];
  final Set<String> _skipped = {};
  final Set<String> _seen = {};
  final Set<String> _likedPosts = {};
  final Set<BoltTopic> _topics = {};
  final List<EveningEntry> _eveningEntries = [];
  final List<DreamEntry> _dreamEntries = [];

  List<Bolt> _deck = [];
  Bolt? _daily;
  String _todayKey = '';
  int _streak = 0;
  int _visitStreak = 0;
  int _totalSwipes = 0;
  bool _dailyClaimed = false;
  bool _haptics = true;
  bool _motion = true;
  String _nickname = 'You';

  // Sleep Ritual: everything below is typed in by hand, never read from a
  // health API or the OS — the feature is fully offline and manual.
  String? _lastMorningDate;
  List<String> _morningChargeDays = [];
  bool _morningChargeEnabled = true;
  bool _eveningDischargeEnabled = true;
  int _eveningReminderMinutes = 21 * 60;

  // ---------------------------------------------------------------- bootstrap

  /// Runs every start-up step and reports honest progress while doing it.
  static Future<AppState> bootstrap(ProgressReport report) async {
    report(0.05, 'Waking the storm');
    final storage = await Storage.open();

    report(0.20, 'Opening the archive');
    final docs = await getApplicationDocumentsDirectory();
    final mediaDir = Directory('${docs.path}/aether_media');
    if (!await mediaDir.exists()) {
      await mediaDir.create(recursive: true);
    }

    final state = AppState._(storage, mediaDir);

    report(0.36, 'Charging the library');
    await state._loadLibrary();

    report(0.60, 'Sharpening the sparks');
    await state._loadSeedFeed();

    report(0.78, 'Restoring your collection');
    state._restoreUserData();

    report(0.90, 'Aligning today\'s bolt');
    await state._resolveDaily();

    report(0.94, 'Counting the days');
    await state._rollVisitStreak();

    report(0.97, 'Shuffling the deck');
    state._rebuildDeck();

    return state;
  }

  /// Passive "days-in-a-row-opened" streak. Runs once per bootstrap so the
  /// first launch of every new calendar day advances (or resets) the count.
  /// Extra launches on the same day are no-ops.
  ///
  /// Rules:
  ///   • same day as the previous visit → keep the current count,
  ///   • exactly one day later          → +1,
  ///   • two or more days gap           → reset to 1 (today still counts).
  Future<void> _rollVisitStreak() async {
    final today = _dayKey(DateTime.now());
    final last = _storage.lastVisitDay;
    if (last == today) {
      _visitStreak = _storage.visitStreak;
      return;
    }
    final yesterday = _dayKey(DateTime.now().subtract(const Duration(days: 1)));
    final previous = _storage.visitStreak;
    _visitStreak = last == yesterday ? previous + 1 : 1;
    await _storage.setVisitStreak(_visitStreak);
    await _storage.setLastVisitDay(today);
  }

  Future<void> _loadLibrary() async {
    final raw = await rootBundle.loadString('assets/content/bolts.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final items = (decoded['bolts'] as List).cast<Map<String, dynamic>>();
    _library
      ..clear()
      ..addAll(items.map(Bolt.fromJson));
  }

  Future<void> _loadSeedFeed() async {
    final raw = await rootBundle.loadString('assets/content/community.json');
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    final items = (decoded['posts'] as List).cast<Map<String, dynamic>>();
    final now = DateTime.now();
    _seedFeed
      ..clear()
      ..addAll(items.map((e) => CommunityPost.fromSeed(e, now)));
  }

  void _restoreUserData() {
    _topics
      ..clear()
      ..addAll(_storage.topics.map(BoltTopicInfo.parse));
    if (_topics.isEmpty) _topics.addAll(BoltTopic.values);

    _saved
      ..clear()
      ..addAll(_storage.savedBolts.map(Bolt.fromJson));
    _myBolts
      ..clear()
      ..addAll(_storage.myBolts.map(Bolt.fromJson));
    _myPosts
      ..clear()
      ..addAll(_storage.myPosts.map(CommunityPost.fromJson));
    _skipped
      ..clear()
      ..addAll(_storage.skippedIds);
    _seen
      ..clear()
      ..addAll(_storage.seenIds);
    _likedPosts
      ..clear()
      ..addAll(_storage.likedPosts);

    _haptics = _storage.haptics;
    _motion = _storage.motion;
    _nickname = _storage.nickname;
    _streak = _storage.streak;
    _visitStreak = _storage.visitStreak;
    _totalSwipes = _storage.totalSwipes;

    _eveningEntries
      ..clear()
      ..addAll(_storage.eveningEntries.map(EveningEntry.fromJson));
    _dreamEntries
      ..clear()
      ..addAll(_storage.dreamEntries.map(DreamEntry.fromJson));
    _lastMorningDate = _storage.lastMorningDate;
    _morningChargeDays = List<String>.from(_storage.morningChargeDays);
    _morningChargeEnabled = _storage.morningChargeEnabled;
    _eveningDischargeEnabled = _storage.eveningDischargeEnabled;
    _eveningReminderMinutes = _storage.eveningReminderMinutes;
  }

  Future<void> _resolveDaily() async {
    _todayKey = _dayKey(DateTime.now());
    _dailyClaimed = _storage.dailyClaimedDay == _todayKey;

    final storedId = _storage.dailyBoltId(_todayKey);
    if (storedId != null) {
      final match = _library.where((b) => b.id == storedId).toList();
      if (match.isNotEmpty) {
        _daily = match.first;
        return;
      }
    }

    final pool = _library.where((b) => _topics.contains(b.topic)).toList();
    final source = pool.isEmpty ? _library : pool;
    if (source.isEmpty) return;
    final seed = _todayKey.hashCode ^ 0x5EED;
    _daily = source[Random(seed).nextInt(source.length)];
    await _storage.setDailyBoltId(_todayKey, _daily!.id);
  }

  void _rebuildDeck() {
    final pool = [
      ..._library.where((b) => _topics.contains(b.topic)),
      ..._myBolts.where((b) => _topics.contains(b.topic)),
    ];
    final source = pool.isEmpty ? List<Bolt>.from(_library) : pool;
    var fresh = source.where((b) => !_seen.contains(b.id)).toList();
    if (fresh.length < 4) {
      // Endless deck: once the pool is exhausted the history resets.
      _seen.clear();
      _storage.setSeenIds(const []);
      fresh = List<Bolt>.from(source);
    }
    fresh.shuffle(Random(DateTime.now().millisecondsSinceEpoch));
    _deck = fresh;
  }

  // ------------------------------------------------------------------ getters

  bool get onboarded => _storage.onboarded;
  Future<void> completeOnboarding() async {
    await _storage.setOnboarded(true);
    notifyListeners();
  }

  List<Bolt> get library => List.unmodifiable(_library);
  List<Bolt> get deck => List.unmodifiable(_deck);
  List<Bolt> get saved => List.unmodifiable(_saved.reversed);
  List<Bolt> get myBolts => List.unmodifiable(_myBolts.reversed);
  Set<BoltTopic> get topics => Set.unmodifiable(_topics);
  Bolt? get dailyBolt => _daily;
  bool get dailyClaimed => _dailyClaimed;
  int get streak => _streak;
  int get visitStreak => _visitStreak;
  int get totalSwipes => _totalSwipes;
  bool get haptics => _haptics;
  bool get motion => _motion;
  String get nickname => _nickname;
  int get skippedCount => _skipped.length;

  List<CommunityPost> get feed {
    final all = [..._myPosts, ..._seedFeed]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(all);
  }

  bool isSaved(String id) => _saved.any((b) => b.id == id);
  bool isLiked(String postId) => _likedPosts.contains(postId);

  int likesOf(CommunityPost post) =>
      post.baseLikes + (_likedPosts.contains(post.id) ? 1 : 0);

  List<Bolt> savedByTopic(BoltTopic? topic) =>
      topic == null ? saved : saved.where((b) => b.topic == topic).toList();

  /// A community post to spotlight on the Today screen.
  CommunityPost? get spotlightPost {
    final list = feed;
    if (list.isEmpty) return null;
    final seed = _todayKey.hashCode ^ 0xC0FFEE;
    return list[Random(seed).nextInt(list.length)];
  }

  // ------------------------------------------------------------ sleep ritual

  String get todayKey => _todayKey;
  String get yesterdayKey => dayKeyFor(DateTime.now().subtract(const Duration(days: 1)));

  List<EveningEntry> get eveningEntries => List.unmodifiable(_eveningEntries.reversed);
  List<DreamEntry> get dreamEntries => List.unmodifiable(_dreamEntries.reversed);

  bool get morningChargeEnabled => _morningChargeEnabled;
  bool get eveningDischargeEnabled => _eveningDischargeEnabled;
  TimeOfDay get eveningReminderTime =>
      TimeOfDay(hour: _eveningReminderMinutes ~/ 60, minute: _eveningReminderMinutes % 60);

  EveningEntry? eveningEntryFor(String dateKey) {
    final matches = _eveningEntries.where((e) => e.dateKey == dateKey);
    return matches.isEmpty ? null : matches.last;
  }

  DreamEntry? dreamEntryFor(String dateKey) {
    final matches = _dreamEntries.where((d) => d.dateKey == dateKey);
    return matches.isEmpty ? null : matches.last;
  }

  bool get eveningDoneToday => eveningEntryFor(_todayKey) != null;

  /// True once it is the first app launch of a new calendar day — this is
  /// exactly what gates the Morning Charge screen right after the splash.
  bool get morningChargePending =>
      _morningChargeEnabled && _lastMorningDate != _todayKey;

  /// True when the soft "Time to discharge" banner should show on Today:
  /// the feature is on, today's evening entry is missing, and the clock has
  /// passed the user's configured reminder time.
  bool get eveningBannerDue {
    if (!_eveningDischargeEnabled) return false;
    if (eveningDoneToday) return false;
    final now = TimeOfDay.now();
    final nowMinutes = now.hour * 60 + now.minute;
    return nowMinutes >= _eveningReminderMinutes;
  }

  /// Consecutive days (ending today or yesterday) with a completed Morning
  /// Charge. Recomputed from the stored day-keys every time, so a gap while
  /// the app was untouched is always reflected correctly.
  int get sleepStreak => computeDailyStreak(_morningChargeDays.toSet(), DateTime.now());

  /// All days (ever) that have a completed Morning Charge, as a set of
  /// canonical dayKeys. Used by the Rituals screen to draw the activity
  /// heatmap.
  Set<String> get morningChargeDayKeys => Set.unmodifiable(_morningChargeDays);

  /// "~7h 30m", only when both last night's bedtime and this morning's wake
  /// time were entered by hand.
  String? get lastNightSummary {
    final wake = dreamEntryFor(_todayKey)?.wakeTime;
    if (wake == null) return null;
    final bed = eveningEntryFor(yesterdayKey)?.bedTime;
    if (bed == null) return null;
    return formatSleepDuration(sleepDurationBetween(bed, wake));
  }

  // ------------------------------------------------------------------ actions

  Future<void> setTopics(Set<BoltTopic> value) async {
    if (value.isEmpty) return;
    _topics
      ..clear()
      ..addAll(value);
    await _storage.setTopics(_topics.map((t) => t.name).toList());
    await _resolveDailyForTopicChange();
    _rebuildDeck();
    notifyListeners();
  }

  Future<void> _resolveDailyForTopicChange() async {
    if (_daily != null && _topics.contains(_daily!.topic)) return;
    final pool = _library.where((b) => _topics.contains(b.topic)).toList();
    if (pool.isEmpty) return;
    _daily = pool[Random(_todayKey.hashCode ^ 0x5EED).nextInt(pool.length)];
    await _storage.setDailyBoltId(_todayKey, _daily!.id);
  }

  Future<void> toggleTopic(BoltTopic topic) async {
    final next = Set<BoltTopic>.from(_topics);
    if (next.contains(topic)) {
      if (next.length == 1) return;
      next.remove(topic);
    } else {
      next.add(topic);
    }
    await setTopics(next);
  }

  Future<void> claimDaily() async {
    if (_dailyClaimed) return;
    final previous = _storage.lastOpenDay;
    final yesterday = _dayKey(DateTime.now().subtract(const Duration(days: 1)));
    _streak = previous == yesterday ? _streak + 1 : 1;
    _dailyClaimed = true;
    await _storage.setStreak(_streak);
    await _storage.setDailyClaimedDay(_todayKey);
    await _storage.setLastOpenDay(_todayKey);
    notifyListeners();
  }

  Future<bool> saveBolt(Bolt bolt) async {
    if (isSaved(bolt.id)) return false;
    _saved.add(bolt);
    await _storage.setSavedBolts(_saved.map((b) => b.toJson()).toList());
    notifyListeners();
    return true;
  }

  Future<void> removeSaved(String id) async {
    _saved.removeWhere((b) => b.id == id);
    await _storage.setSavedBolts(_saved.map((b) => b.toJson()).toList());
    notifyListeners();
  }

  Future<void> toggleSaved(Bolt bolt) async {
    if (isSaved(bolt.id)) {
      await removeSaved(bolt.id);
    } else {
      await saveBolt(bolt);
    }
  }

  /// Called by the swipe deck. [liked] right, [skipped] left.
  Future<void> registerSwipe(Bolt bolt, {required bool liked}) async {
    _seen.add(bolt.id);
    _totalSwipes += 1;
    if (liked) {
      if (!isSaved(bolt.id)) _saved.add(bolt);
      await _storage.setSavedBolts(_saved.map((b) => b.toJson()).toList());
    } else {
      _skipped.add(bolt.id);
      await _storage.setSkippedIds(_skipped.toList());
    }
    await _storage.setSeenIds(_seen.toList());
    await _storage.setTotalSwipes(_totalSwipes);
    if (_deck.isNotEmpty) _deck = List<Bolt>.from(_deck)..removeAt(0);
    if (_deck.length < 3) _rebuildDeck();
    notifyListeners();
  }

  Future<void> reshuffleDeck() async {
    _rebuildDeck();
    notifyListeners();
  }

  Future<Bolt> createBolt({
    required String text,
    required BoltKind kind,
    required BoltTopic topic,
    String? author,
    String? imagePath,
    String? audioPath,
    List<String> words = const [],
    int palette = 0,
  }) async {
    final bolt = Bolt(
      id: 'mine-${DateTime.now().microsecondsSinceEpoch}',
      kind: kind,
      topic: topic,
      text: text.trim(),
      author: (author == null || author.trim().isEmpty) ? null : author.trim(),
      words: words,
      palette: palette,
      imagePath: imagePath,
      audioPath: audioPath,
      createdBy: _nickname,
      createdAt: DateTime.now(),
    );
    _myBolts.add(bolt);
    await _storage.setMyBolts(_myBolts.map((b) => b.toJson()).toList());
    notifyListeners();
    return bolt;
  }

  Future<void> publish(Bolt bolt) async {
    final post = CommunityPost(
      id: 'mypost-${DateTime.now().microsecondsSinceEpoch}',
      author: _nickname,
      handle: '@${_nickname.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}',
      avatar: _nickname.hashCode.abs() % 16,
      bolt: bolt,
      baseLikes: 0,
      createdAt: DateTime.now(),
      mine: true,
    );
    _myPosts.insert(0, post);
    await _storage.setMyPosts(_myPosts.map((p) => p.toJson()).toList());
    notifyListeners();
  }

  Future<void> deletePost(String id) async {
    _myPosts.removeWhere((p) => p.id == id);
    await _storage.setMyPosts(_myPosts.map((p) => p.toJson()).toList());
    notifyListeners();
  }

  Future<void> toggleLike(String postId) async {
    if (_likedPosts.contains(postId)) {
      _likedPosts.remove(postId);
    } else {
      _likedPosts.add(postId);
    }
    await _storage.setLikedPosts(_likedPosts.toList());
    notifyListeners();
  }

  Future<void> setHaptics(bool value) async {
    _haptics = value;
    await _storage.setHaptics(value);
    notifyListeners();
  }

  Future<void> setMotion(bool value) async {
    _motion = value;
    await _storage.setMotion(value);
    notifyListeners();
  }

  Future<void> setNickname(String value) async {
    final trimmed = value.trim();
    _nickname = trimmed.isEmpty ? 'You' : trimmed;
    await _storage.setNickname(_nickname);
    notifyListeners();
  }

  // ------------------------------------------------------------ sleep ritual

  /// One entry per evening: saving again the same day overwrites it.
  Future<void> saveEveningEntry(EveningEntry entry) async {
    _eveningEntries.removeWhere((e) => e.dateKey == entry.dateKey);
    _eveningEntries.add(entry);
    await _storage.setEveningEntries(_eveningEntries.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  /// The gate action behind the sleep streak: marks today's Morning Charge
  /// as done. Calling it again the same day is a harmless no-op.
  Future<void> completeMorningCharge() async {
    if (_lastMorningDate == _todayKey) return;
    _lastMorningDate = _todayKey;
    if (!_morningChargeDays.contains(_todayKey)) {
      _morningChargeDays = [..._morningChargeDays, _todayKey];
    }
    await _storage.setLastMorningDate(_todayKey);
    await _storage.setMorningChargeDays(_morningChargeDays);
    notifyListeners();
  }

  /// One entry per morning: saving again the same day overwrites it.
  Future<void> saveDream(DreamEntry entry) async {
    _dreamEntries.removeWhere((d) => d.dateKey == entry.dateKey);
    _dreamEntries.add(entry);
    await _storage.setDreamEntries(_dreamEntries.map((d) => d.toJson()).toList());
    notifyListeners();
  }

  Future<void> deleteDream(String id) async {
    _dreamEntries.removeWhere((d) => d.id == id);
    await _storage.setDreamEntries(_dreamEntries.map((d) => d.toJson()).toList());
    notifyListeners();
  }

  /// Turns a dream entry into a community post — folding the tags, waking
  /// mood and sleep length into plain text so the existing feed/bolt models
  /// never need a schema change for it.
  Future<void> shareDreamToFeed(DreamEntry entry) async {
    final body = StringBuffer(
      entry.text.trim().isEmpty ? 'A dream, kept without words.' : entry.text.trim(),
    );
    if (entry.mood != null) {
      body.write('\n\nWaking mood: ${entry.mood!.label}');
    }
    if (entry.sleepDurationMinutes != null) {
      body.write('\nSlept ~${formatSleepDuration(Duration(minutes: entry.sleepDurationMinutes!))}');
    }
    final bolt = Bolt(
      id: 'dream-${DateTime.now().microsecondsSinceEpoch}',
      kind: BoltKind.dream,
      // Dream bolts are never added to the library or the deck, so the
      // topic below is only used for display — it never affects rotation.
      topic: BoltTopic.creativity,
      text: body.toString(),
      words: entry.tags.map((t) => t.label).toList(),
      createdBy: _nickname,
      createdAt: DateTime.now(),
    );
    await publish(bolt);
  }

  /// Saves the day's word+quote straight to the Saved collection.
  Future<Bolt> saveMorningCharge({required String word, required String quote}) async {
    final bolt = Bolt(
      id: 'morning-${DateTime.now().microsecondsSinceEpoch}',
      kind: BoltKind.morningCharge,
      topic: BoltTopic.motivation,
      text: quote,
      words: [word],
      createdBy: _nickname,
      createdAt: DateTime.now(),
    );
    await saveBolt(bolt);
    return bolt;
  }

  Future<void> setMorningChargeEnabled(bool value) async {
    _morningChargeEnabled = value;
    await _storage.setMorningChargeEnabled(value);
    notifyListeners();
  }

  Future<void> setEveningDischargeEnabled(bool value) async {
    _eveningDischargeEnabled = value;
    await _storage.setEveningDischargeEnabled(value);
    notifyListeners();
  }

  Future<void> setEveningReminderTime(TimeOfDay time) async {
    _eveningReminderMinutes = time.hour * 60 + time.minute;
    await _storage.setEveningReminderMinutes(_eveningReminderMinutes);
    notifyListeners();
  }

  Future<void> resetEverything() async {
    await _storage.wipe();
    _saved.clear();
    _myBolts.clear();
    _myPosts.clear();
    _skipped.clear();
    _seen.clear();
    _likedPosts.clear();
    _topics
      ..clear()
      ..addAll(BoltTopic.values);
    _streak = 0;
    _visitStreak = 0;
    _totalSwipes = 0;
    _dailyClaimed = false;
    _haptics = true;
    _motion = true;
    _nickname = 'You';
    _eveningEntries.clear();
    _dreamEntries.clear();
    _lastMorningDate = null;
    _morningChargeDays = [];
    _morningChargeEnabled = true;
    _eveningDischargeEnabled = true;
    _eveningReminderMinutes = 21 * 60;
    if (await _mediaDir.exists()) {
      for (final entity in _mediaDir.listSync()) {
        try {
          entity.deleteSync(recursive: true);
        } catch (_) {}
      }
    }
    await _resolveDaily();
    await _rollVisitStreak();
    _rebuildDeck();
    notifyListeners();
  }

  /// Copies a picked/recorded file into the app sandbox so it survives
  /// cache clean-ups, and returns the permanent path.
  Future<String> adoptMedia(String sourcePath, String prefix) async {
    final ext = sourcePath.contains('.') ? sourcePath.split('.').last : 'dat';
    final target =
        '${_mediaDir.path}/$prefix-${DateTime.now().microsecondsSinceEpoch}.$ext';
    await File(sourcePath).copy(target);
    return target;
  }

  String get mediaDirPath => _mediaDir.path;

  static String _dayKey(DateTime date) => dayKeyFor(date);

  String get todayLabel {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final now = DateTime.now();
    return '${months[now.month - 1]} ${now.day}, ${now.year}';
  }

  /// Warm time-of-day greeting for the Today screen. Uses the user's
  /// [nickname] when it has been personalised — the placeholder `'You'`
  /// would read awkwardly ("Good morning, You"), so in that case we drop
  /// the name and keep only the time-of-day salutation.
  String get greeting {
    final hour = DateTime.now().hour;
    final part = hour < 5
        ? 'Good night'
        : hour < 12
            ? 'Good morning'
            : hour < 18
                ? 'Good afternoon'
                : 'Good evening';
    if (_nickname.isEmpty || _nickname == 'You') return part;
    return '$part, $_nickname';
  }
}
