import 'package:flutter/material.dart';

import 'app_palette.dart';

/// [dream] and [morningCharge] are system-generated kinds produced by the
/// Sleep Ritual feature (dream journal shares, morning word+quote saves).
/// They are deliberately left out of the Create screen's picker.
enum BoltKind { quote, affirmation, fact, collage, dream, morningCharge }

enum BoltTopic { motivation, love, creativity, humor }

extension BoltKindInfo on BoltKind {
  String get id => name;

  String get label => switch (this) {
        BoltKind.quote => 'Quote',
        BoltKind.affirmation => 'Affirmation',
        BoltKind.fact => 'Odd fact',
        BoltKind.collage => 'Collage',
        BoltKind.dream => 'Dream',
        BoltKind.morningCharge => 'Morning charge',
      };

  IconData get icon => switch (this) {
        BoltKind.quote => Icons.format_quote_rounded,
        BoltKind.affirmation => Icons.self_improvement_rounded,
        BoltKind.fact => Icons.auto_awesome_rounded,
        BoltKind.collage => Icons.grid_view_rounded,
        BoltKind.dream => Icons.nightlight_round,
        BoltKind.morningCharge => Icons.wb_sunny_rounded,
      };

  static BoltKind parse(String? value) => BoltKind.values.firstWhere(
        (k) => k.name == value,
        orElse: () => BoltKind.affirmation,
      );
}

/// Five-point mood scale reused by both the evening and morning rituals.
enum RitualMood { radiant, good, okay, low, heavy }

extension RitualMoodInfo on RitualMood {
  String get label => switch (this) {
        RitualMood.radiant => 'Radiant',
        RitualMood.good => 'Good',
        RitualMood.okay => 'Okay',
        RitualMood.low => 'Low',
        RitualMood.heavy => 'Heavy',
      };

  IconData get icon => switch (this) {
        RitualMood.radiant => Icons.sentiment_very_satisfied_rounded,
        RitualMood.good => Icons.sentiment_satisfied_rounded,
        RitualMood.okay => Icons.sentiment_neutral_rounded,
        RitualMood.low => Icons.sentiment_dissatisfied_rounded,
        RitualMood.heavy => Icons.sentiment_very_dissatisfied_rounded,
      };

  static RitualMood? parse(String? value) {
    if (value == null) return null;
    for (final mood in RitualMood.values) {
      if (mood.name == value) return mood;
    }
    return null;
  }
}

/// Multi-select dream-journal descriptors.
enum DreamTag { nightmare, vivid, strange, lucid, forgot }

extension DreamTagInfo on DreamTag {
  String get label => switch (this) {
        DreamTag.nightmare => 'Nightmare',
        DreamTag.vivid => 'Vivid',
        DreamTag.strange => 'Strange',
        DreamTag.lucid => 'Lucid',
        DreamTag.forgot => 'Forgot',
      };

  IconData get icon => switch (this) {
        DreamTag.nightmare => Icons.dark_mode_rounded,
        DreamTag.vivid => Icons.blur_on_rounded,
        DreamTag.strange => Icons.psychology_alt_rounded,
        DreamTag.lucid => Icons.visibility_rounded,
        DreamTag.forgot => Icons.help_outline_rounded,
      };

  static DreamTag? parse(String value) {
    for (final tag in DreamTag.values) {
      if (tag.name == value) return tag;
    }
    return null;
  }
}

int? timeOfDayToMinutes(TimeOfDay? time) =>
    time == null ? null : time.hour * 60 + time.minute;

TimeOfDay? minutesToTimeOfDay(num? minutes) => minutes == null
    ? null
    : TimeOfDay(hour: minutes ~/ 60, minute: (minutes % 60).toInt());

extension BoltTopicInfo on BoltTopic {
  String get id => name;

  String get label => switch (this) {
        BoltTopic.motivation => 'Motivation',
        BoltTopic.love => 'Love',
        BoltTopic.creativity => 'Creativity',
        BoltTopic.humor => 'Humor',
      };

  String get blurb => switch (this) {
        BoltTopic.motivation => 'Fuel, grit and momentum',
        BoltTopic.love => 'Warmth, people, self-worth',
        BoltTopic.creativity => 'Ideas, making, curiosity',
        BoltTopic.humor => 'Light, odd and absurd',
      };

  IconData get icon => switch (this) {
        BoltTopic.motivation => Icons.bolt_rounded,
        BoltTopic.love => Icons.favorite_rounded,
        BoltTopic.creativity => Icons.palette_rounded,
        BoltTopic.humor => Icons.mood_rounded,
      };

  Color get color => switch (this) {
        BoltTopic.motivation => AetherColors.sky,
        BoltTopic.love => AetherColors.rose,
        BoltTopic.creativity => AetherColors.violet,
        BoltTopic.humor => AetherColors.mint,
      };

  static BoltTopic parse(String? value) => BoltTopic.values.firstWhere(
        (t) => t.name == value,
        orElse: () => BoltTopic.motivation,
      );
}

/// A single "bolt" — the atomic piece of content the whole app revolves around.
@immutable
class Bolt {
  const Bolt({
    required this.id,
    required this.kind,
    required this.topic,
    required this.text,
    this.author,
    this.words = const [],
    this.palette = 0,
    this.imagePath,
    this.audioPath,
    this.createdBy,
    this.createdAt,
  });

  final String id;
  final BoltKind kind;
  final BoltTopic topic;
  final String text;
  final String? author;

  /// Word cluster used to build a generated collage.
  final List<String> words;
  final int palette;

  /// Local file paths for user attachments (never leave the device).
  final String? imagePath;
  final String? audioPath;

  final String? createdBy;
  final DateTime? createdAt;

  bool get isMine => createdBy != null;
  bool get hasImage => imagePath != null && imagePath!.isNotEmpty;
  bool get hasAudio => audioPath != null && audioPath!.isNotEmpty;

  factory Bolt.fromJson(Map<String, dynamic> json) {
    return Bolt(
      id: json['id'] as String,
      kind: BoltKindInfo.parse(json['type'] as String?),
      topic: BoltTopicInfo.parse(json['theme'] as String?),
      text: (json['text'] as String?) ?? '',
      author: json['author'] as String?,
      words: (json['words'] as List?)?.map((e) => e.toString()).toList() ?? const [],
      palette: (json['palette'] as num?)?.toInt() ?? 0,
      imagePath: json['imagePath'] as String?,
      audioPath: json['audioPath'] as String?,
      createdBy: json['createdBy'] as String?,
      createdAt: json['createdAt'] == null
          ? null
          : DateTime.tryParse(json['createdAt'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': kind.name,
        'theme': topic.name,
        'text': text,
        if (author != null) 'author': author,
        if (words.isNotEmpty) 'words': words,
        'palette': palette,
        if (imagePath != null) 'imagePath': imagePath,
        if (audioPath != null) 'audioPath': audioPath,
        if (createdBy != null) 'createdBy': createdBy,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  Bolt copyWith({String? id, String? imagePath, String? audioPath}) => Bolt(
        id: id ?? this.id,
        kind: kind,
        topic: topic,
        text: text,
        author: author,
        words: words,
        palette: palette,
        imagePath: imagePath ?? this.imagePath,
        audioPath: audioPath ?? this.audioPath,
        createdBy: createdBy,
        createdAt: createdAt,
      );
}

/// A bolt shared into the community feed.
@immutable
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.author,
    required this.handle,
    required this.avatar,
    required this.bolt,
    required this.baseLikes,
    required this.createdAt,
    this.mine = false,
  });

  final String id;
  final String author;
  final String handle;
  final int avatar;
  final Bolt bolt;
  final int baseLikes;
  final DateTime createdAt;
  final bool mine;

  factory CommunityPost.fromSeed(Map<String, dynamic> json, DateTime now) {
    final hours = (json['hoursAgo'] as num?)?.toInt() ?? 0;
    // The seed's `author` is the poster, not a quote attribution, so it is
    // stripped before the bolt itself is parsed.
    final boltJson = Map<String, dynamic>.from(json)
      ..remove('author')
      ..['id'] = 'post-${json['id']}';
    return CommunityPost(
      id: json['id'] as String,
      author: json['author'] as String,
      handle: json['handle'] as String? ?? '@aether',
      avatar: (json['avatar'] as num?)?.toInt() ?? 0,
      baseLikes: (json['likes'] as num?)?.toInt() ?? 0,
      createdAt: now.subtract(Duration(hours: hours)),
      bolt: Bolt.fromJson(boltJson),
    );
  }

  factory CommunityPost.fromJson(Map<String, dynamic> json) => CommunityPost(
        id: json['id'] as String,
        author: json['author'] as String,
        handle: json['handle'] as String? ?? '@you',
        avatar: (json['avatar'] as num?)?.toInt() ?? 0,
        baseLikes: (json['likes'] as num?)?.toInt() ?? 0,
        createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
        mine: json['mine'] as bool? ?? false,
        bolt: Bolt.fromJson(json['bolt'] as Map<String, dynamic>),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'author': author,
        'handle': handle,
        'avatar': avatar,
        'likes': baseLikes,
        'createdAt': createdAt.toIso8601String(),
        'mine': mine,
        'bolt': bolt.toJson(),
      };
}

/// One evening's reflection: three short prompts, a mood, and — only if the
/// user chooses to type it in — the time they say they are going to sleep.
/// Nothing here is read from the device; it is all typed by hand.
@immutable
class EveningEntry {
  const EveningEntry({
    required this.dateKey,
    required this.wentWell,
    required this.grateful,
    required this.intention,
    required this.createdAt,
    this.mood,
    this.bedTime,
  });

  /// Calendar day (yyyy-MM-dd) this discharge belongs to.
  final String dateKey;
  final String wentWell;
  final String grateful;
  final String intention;
  final RitualMood? mood;
  final TimeOfDay? bedTime;
  final DateTime createdAt;

  factory EveningEntry.fromJson(Map<String, dynamic> json) => EveningEntry(
        dateKey: json['dateKey'] as String,
        wentWell: json['wentWell'] as String? ?? '',
        grateful: json['grateful'] as String? ?? '',
        intention: json['intention'] as String? ?? '',
        mood: RitualMoodInfo.parse(json['mood'] as String?),
        bedTime: minutesToTimeOfDay(json['bedTime'] as num?),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'dateKey': dateKey,
        'wentWell': wentWell,
        'grateful': grateful,
        'intention': intention,
        if (mood != null) 'mood': mood!.name,
        if (bedTime != null) 'bedTime': timeOfDayToMinutes(bedTime),
        'createdAt': createdAt.toIso8601String(),
      };
}

/// A morning's dream-journal entry. Every field is optional — the whole
/// point of the Dream Journal is that "Skip" is always a fine answer.
@immutable
class DreamEntry {
  const DreamEntry({
    required this.id,
    required this.dateKey,
    required this.createdAt,
    this.text = '',
    this.tags = const [],
    this.mood,
    this.wakeTime,
    this.sleepDurationMinutes,
  });

  final String id;

  /// Calendar day (yyyy-MM-dd) of the morning this dream was logged on.
  final String dateKey;
  final String text;
  final List<DreamTag> tags;
  final RitualMood? mood;
  final TimeOfDay? wakeTime;
  final int? sleepDurationMinutes;
  final DateTime createdAt;

  bool get hasContent => text.trim().isNotEmpty || tags.isNotEmpty;

  factory DreamEntry.fromJson(Map<String, dynamic> json) => DreamEntry(
        id: json['id'] as String,
        dateKey: json['dateKey'] as String,
        text: json['text'] as String? ?? '',
        tags: (json['tags'] as List?)
                ?.map((e) => DreamTagInfo.parse(e.toString()))
                .whereType<DreamTag>()
                .toList() ??
            const [],
        mood: RitualMoodInfo.parse(json['mood'] as String?),
        wakeTime: minutesToTimeOfDay(json['wakeTime'] as num?),
        sleepDurationMinutes: (json['sleepDurationMinutes'] as num?)?.toInt(),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'dateKey': dateKey,
        'text': text,
        'tags': tags.map((t) => t.name).toList(),
        if (mood != null) 'mood': mood!.name,
        if (wakeTime != null) 'wakeTime': timeOfDayToMinutes(wakeTime),
        if (sleepDurationMinutes != null) 'sleepDurationMinutes': sleepDurationMinutes,
        'createdAt': createdAt.toIso8601String(),
      };
}
