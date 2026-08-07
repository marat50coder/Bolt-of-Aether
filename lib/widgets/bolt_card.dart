import 'dart:io';

import 'package:flutter/material.dart';

import '../core/app_palette.dart';
import '../core/models.dart';
import 'collage_view.dart';
import 'glass.dart';
import 'voice_note.dart';

/// The hero presentation of a bolt: used on Daily and in the swipe deck.
class BoltCard extends StatelessWidget {
  const BoltCard({super.key, required this.bolt, this.footer, this.showAudio = true});

  final Bolt bolt;
  final Widget? footer;
  final bool showAudio;

  @override
  Widget build(BuildContext context) {
    final accent = bolt.topic.color;

    return GlassPanel(
      padding: const EdgeInsets.all(20),
      radius: 30,
      glowColor: accent,
      fill: const Color(0x1AFFFFFF),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AetherTag(label: bolt.kind.label, icon: bolt.kind.icon, color: AetherColors.goldLight),
              if (bolt.kind != BoltKind.dream) ...[
                const SizedBox(width: 8),
                AetherTag(label: bolt.topic.label, icon: bolt.topic.icon, color: accent),
              ],
              const Spacer(),
              if (bolt.isMine)
                const AetherTag(label: 'Yours', icon: Icons.person_rounded, dense: true),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: BoltContent(bolt: bolt, showAudio: showAudio),
            ),
          ),
          if (footer != null) ...[const SizedBox(height: 14), footer!],
        ],
      ),
    );
  }
}

/// Type-aware body of a bolt, reused by every screen.
class BoltContent extends StatelessWidget {
  const BoltContent({
    super.key,
    required this.bolt,
    this.showAudio = true,
    this.dense = false,
  });

  final Bolt bolt;
  final bool showAudio;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final accent = bolt.topic.color;
    final children = <Widget>[];

    if (bolt.hasImage) {
      children.add(_Photo(path: bolt.imagePath!, dense: dense));
      children.add(SizedBox(height: dense ? 10 : 16));
    } else if (bolt.kind == BoltKind.collage) {
      children.add(CollageView(bolt: bolt, compact: dense));
      children.add(SizedBox(height: dense ? 10 : 16));
    }

    switch (bolt.kind) {
      case BoltKind.quote:
        children.add(_QuoteBody(bolt: bolt, dense: dense));
      case BoltKind.affirmation:
        children.add(_AffirmationBody(bolt: bolt, dense: dense));
      case BoltKind.fact:
        children.add(_FactBody(bolt: bolt, dense: dense));
      case BoltKind.collage:
        children.add(
          Text(
            bolt.text,
            style: TextStyle(
              fontSize: dense ? 14 : 17,
              height: 1.4,
              color: AetherColors.ivory,
              fontWeight: FontWeight.w600,
              fontStyle: FontStyle.italic,
            ),
          ),
        );
      case BoltKind.dream:
        children.add(_DreamBody(bolt: bolt, dense: dense));
      case BoltKind.morningCharge:
        children.add(_MorningChargeBody(bolt: bolt, dense: dense));
    }

    if (showAudio && bolt.hasAudio) {
      children.add(SizedBox(height: dense ? 10 : 16));
      children.add(VoiceNoteBar(path: bolt.audioPath!, accent: accent));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: children,
    );
  }
}

double _autoSize(String text, {required bool dense}) {
  final length = text.length;
  final double base;
  if (length < 60) {
    base = 30;
  } else if (length < 110) {
    base = 25;
  } else if (length < 170) {
    base = 21;
  } else {
    base = 18;
  }
  return dense ? base * 0.62 : base;
}

class _QuoteBody extends StatelessWidget {
  const _QuoteBody({required this.bolt, required this.dense});

  final Bolt bolt;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!dense)
          Icon(
            Icons.format_quote_rounded,
            color: AetherColors.goldLight.withValues(alpha: 0.55),
            size: 34,
          ),
        Text(
          bolt.text,
          style: TextStyle(
            fontSize: _autoSize(bolt.text, dense: dense),
            height: 1.28,
            fontWeight: FontWeight.w700,
            color: AetherColors.ivory,
            letterSpacing: -0.2,
          ),
        ),
        if (bolt.author != null && bolt.author!.isNotEmpty) ...[
          SizedBox(height: dense ? 6 : 14),
          Row(
            children: [
              Container(
                width: 22,
                height: 2,
                color: AetherColors.gold.withValues(alpha: 0.8),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  bolt.author!,
                  style: TextStyle(
                    color: AetherColors.gold,
                    fontSize: dense ? 11.5 : 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _AffirmationBody extends StatelessWidget {
  const _AffirmationBody({required this.bolt, required this.dense});

  final Bolt bolt;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!dense)
          Row(
            children: [
              Icon(Icons.bolt_rounded, size: 18, color: bolt.topic.color),
              const SizedBox(width: 6),
              Text(
                'REPEAT IT ONCE, OUT LOUD',
                style: TextStyle(
                  color: bolt.topic.color.withValues(alpha: 0.9),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        if (!dense) const SizedBox(height: 12),
        Text(
          bolt.text,
          style: TextStyle(
            fontSize: _autoSize(bolt.text, dense: dense),
            height: 1.3,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

class _FactBody extends StatelessWidget {
  const _FactBody({required this.bolt, required this.dense});

  final Bolt bolt;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!dense)
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 17, color: AetherColors.goldLight),
              const SizedBox(width: 6),
              Text(
                'ODD BUT TRUE',
                style: TextStyle(
                  color: AetherColors.goldLight.withValues(alpha: 0.9),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
        if (!dense) const SizedBox(height: 12),
        Text(
          bolt.text,
          style: TextStyle(
            fontSize: _autoSize(bolt.text, dense: dense) * 0.92,
            height: 1.42,
            fontWeight: FontWeight.w600,
            color: AetherColors.ivory,
          ),
        ),
      ],
    );
  }
}

class _DreamBody extends StatelessWidget {
  const _DreamBody({required this.bolt, required this.dense});

  final Bolt bolt;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!dense)
          Row(
            children: [
              const Icon(Icons.nightlight_round, size: 17, color: AetherColors.violet),
              const SizedBox(width: 6),
              Text(
                'FROM THE DREAM JOURNAL',
                style: TextStyle(
                  color: AetherColors.violet.withValues(alpha: 0.9),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        if (!dense) const SizedBox(height: 12),
        Text(
          bolt.text,
          style: TextStyle(
            fontSize: _autoSize(bolt.text, dense: dense) * 0.72,
            height: 1.4,
            fontWeight: FontWeight.w600,
            color: AetherColors.ivory,
          ),
        ),
        if (bolt.words.isNotEmpty) ...[
          SizedBox(height: dense ? 8 : 14),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final tag in bolt.words)
                AetherTag(label: tag, color: AetherColors.violet, dense: true),
            ],
          ),
        ],
      ],
    );
  }
}

class _MorningChargeBody extends StatelessWidget {
  const _MorningChargeBody({required this.bolt, required this.dense});

  final Bolt bolt;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final word = bolt.words.isNotEmpty ? bolt.words.first : 'Charge';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!dense)
          Row(
            children: [
              const Icon(Icons.wb_sunny_rounded, size: 17, color: AetherColors.goldLight),
              const SizedBox(width: 6),
              Text(
                'WORD OF THE DAY',
                style: TextStyle(
                  color: AetherColors.goldLight.withValues(alpha: 0.9),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        if (!dense) const SizedBox(height: 10),
        Text(
          word,
          style: TextStyle(
            fontSize: dense ? 18 : 26,
            fontWeight: FontWeight.w900,
            color: AetherColors.goldLight,
          ),
        ),
        SizedBox(height: dense ? 6 : 12),
        Text(
          bolt.text,
          style: TextStyle(
            fontSize: _autoSize(bolt.text, dense: dense) * 0.72,
            height: 1.35,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w600,
            color: AetherColors.ivory,
          ),
        ),
      ],
    );
  }
}

class _Photo extends StatelessWidget {
  const _Photo({required this.path, required this.dense});

  final String path;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(dense ? 14 : 20),
      child: AspectRatio(
        aspectRatio: dense ? 16 / 10 : 4 / 3,
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (context, _, _) => Container(
            color: AetherColors.dusk,
            alignment: Alignment.center,
            child: const Icon(Icons.broken_image_rounded, color: AetherColors.muted),
          ),
        ),
      ),
    );
  }
}

/// Compact row used in Saved and Community lists.
class BoltTile extends StatelessWidget {
  const BoltTile({
    super.key,
    required this.bolt,
    this.onTap,
    this.trailing,
    this.header,
  });

  final Bolt bolt;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: onTap,
      padding: const EdgeInsets.all(15),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[header!, const SizedBox(height: 12)],
          Row(
            children: [
              AetherTag(
                label: bolt.kind.label,
                icon: bolt.kind.icon,
                color: AetherColors.goldLight,
                dense: true,
              ),
              if (bolt.kind != BoltKind.dream) ...[
                const SizedBox(width: 6),
                AetherTag(
                  label: bolt.topic.label,
                  icon: bolt.topic.icon,
                  color: bolt.topic.color,
                  dense: true,
                ),
              ],
              const Spacer(),
              ?trailing,
            ],
          ),
          const SizedBox(height: 12),
          BoltContent(bolt: bolt, dense: true),
        ],
      ),
    );
  }
}
