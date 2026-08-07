import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../core/app_palette.dart';

/// Compact player for a recorded voice bolt.
class VoiceNoteBar extends StatefulWidget {
  const VoiceNoteBar({super.key, required this.path, this.accent = AetherColors.electric});

  final String path;
  final Color accent;

  @override
  State<VoiceNoteBar> createState() => _VoiceNoteBarState();
}

class _VoiceNoteBarState extends State<VoiceNoteBar> {
  final AudioPlayer _player = AudioPlayer();
  final List<StreamSubscription<dynamic>> _subs = [];

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;
  bool _broken = false;

  @override
  void initState() {
    super.initState();
    _broken = !File(widget.path).existsSync();
    _subs.addAll([
      _player.onDurationChanged.listen((d) => setState(() => _duration = d)),
      _player.onPositionChanged.listen((p) => setState(() => _position = p)),
      _player.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          _playing = false;
          _position = Duration.zero;
        });
      }),
    ]);
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_broken) return;
    try {
      if (_playing) {
        await _player.pause();
        if (mounted) setState(() => _playing = false);
      } else {
        await _player.play(DeviceFileSource(widget.path));
        if (mounted) setState(() => _playing = true);
      }
    } catch (_) {
      if (mounted) setState(() => _broken = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _duration.inMilliseconds == 0
        ? 0.0
        : (_position.inMilliseconds / _duration.inMilliseconds).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: widget.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: widget.accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: _toggle,
            customBorder: const CircleBorder(),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.accent.withValues(alpha: 0.22),
              ),
              child: Icon(
                _broken
                    ? Icons.mic_off_rounded
                    : (_playing ? Icons.pause_rounded : Icons.play_arrow_rounded),
                color: widget.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _Waveform(progress: progress, accent: widget.accent, seed: widget.path.hashCode),
          ),
          const SizedBox(width: 10),
          Text(
            _broken ? '--:--' : _format(_playing ? _position : _duration),
            style: TextStyle(
              color: widget.accent,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              fontFeatures: const [],
            ),
          ),
        ],
      ),
    );
  }

  static String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.progress, required this.accent, required this.seed});

  final double progress;
  final Color accent;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final random = Random(seed);
    final bars = List.generate(26, (_) => 0.25 + random.nextDouble() * 0.75);
    return SizedBox(
      height: 26,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < bars.length; i++)
                Container(
                  width: 2.6,
                  height: 26 * bars[i],
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    color: accent.withValues(
                      alpha: i / bars.length <= progress ? 0.95 : 0.32,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
