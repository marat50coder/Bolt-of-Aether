import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../studio/app_palette.dart';
import '../studio/app_scope.dart';
import '../studio/models.dart';
import '../surface/bolt_card.dart';
import '../surface/glass.dart';
import '../surface/voice_note.dart';
import 'home_shell.dart';

/// Compose your own bolt: text, a photo, a voice note, or a word collage.
class CreateScreen extends StatefulWidget {
  const CreateScreen({super.key});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  final TextEditingController _text = TextEditingController();
  final TextEditingController _author = TextEditingController();
  final TextEditingController _word = TextEditingController();
  final AudioRecorder _recorder = AudioRecorder();
  final ImagePicker _picker = ImagePicker();

  BoltKind _kind = BoltKind.affirmation;
  BoltTopic _topic = BoltTopic.motivation;
  final List<String> _words = [];
  int _palette = 0;
  String? _imagePath;
  String? _audioPath;

  bool _recording = false;
  Duration _recorded = Duration.zero;
  Timer? _timer;
  bool _busy = false;

  @override
  void dispose() {
    _timer?.cancel();
    _text.dispose();
    _author.dispose();
    _word.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Bolt get _preview => Bolt(
        id: 'preview',
        kind: _kind,
        topic: _topic,
        text: _text.text.trim().isEmpty
            ? 'Your words show up here as you type.'
            : _text.text.trim(),
        author: _author.text.trim().isEmpty ? null : _author.text.trim(),
        words: _words,
        palette: _palette,
        imagePath: _imagePath,
        audioPath: _audioPath,
        createdBy: AppScope.read(context).nickname,
        createdAt: DateTime.now(),
      );

  // ------------------------------------------------------------------- photo

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1600,
        imageQuality: 88,
      );
      if (file == null || !mounted) return;
      final path = await AppScope.read(context).adoptMedia(file.path, 'photo');
      if (!mounted) return;
      setState(() => _imagePath = path);
    } catch (_) {
      _toast('Could not attach that image');
    }
  }

  void _photoSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AetherColors.deep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AetherColors.electric),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickPhoto(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded, color: AetherColors.electric),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pickPhoto(ImageSource.camera);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- voice

  Future<void> _toggleRecording() async {
    if (_recording) {
      final path = await _recorder.stop();
      _timer?.cancel();
      if (!mounted) return;
      setState(() {
        _recording = false;
        if (path != null) _audioPath = path;
      });
      return;
    }

    final allowed = await _recorder.hasPermission();
    if (!allowed) {
      _toast('Microphone permission is needed for voice bolts');
      return;
    }
    if (!mounted) return;

    final dir = AppScope.read(context).mediaDirPath;
    final path = '$dir/voice-${DateTime.now().microsecondsSinceEpoch}.m4a';
    try {
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000),
        path: path,
      );
    } catch (_) {
      _toast('Recording is not available on this device');
      return;
    }
    if (!mounted) return;

    setState(() {
      _recording = true;
      _recorded = Duration.zero;
      _audioPath = null;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _recorded = Duration(seconds: timer.tick));
      if (timer.tick >= 60) _toggleRecording();
    });
  }

  Future<void> _dropAudio() async {
    final path = _audioPath;
    setState(() => _audioPath = null);
    if (path == null) return;
    try {
      final file = File(path);
      if (file.existsSync()) await file.delete();
    } catch (_) {}
  }

  // ------------------------------------------------------------------ submit

  Future<void> _submit({required bool publish}) async {
    if (_text.text.trim().length < 3) {
      _toast('Write a few words first');
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);

    final state = AppScope.read(context);
    final bolt = await state.createBolt(
      text: _text.text,
      kind: _kind,
      topic: _topic,
      author: _kind == BoltKind.quote ? _author.text : null,
      imagePath: _imagePath,
      audioPath: _audioPath,
      words: List<String>.from(_words),
      palette: _palette,
    );
    await state.saveBolt(bolt);
    if (publish) await state.publish(bolt);
    if (!mounted) return;

    setState(() {
      _busy = false;
      _text.clear();
      _author.clear();
      _words.clear();
      _imagePath = null;
      _audioPath = null;
      _recorded = Duration.zero;
    });

    _toast('Saved to your collection');
    HomeNav.jump(context, 4);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
      children: [
        ShaderText(
          'Create a bolt',
          style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: -0.5),
        ),
        const SizedBox(height: 2),
        Text(
          'Write it, snap it, or say it out loud.',
          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.68)),
        ),
        const SizedBox(height: 20),
        const SectionTitle('Kind'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            // Dream and Morning Charge bolts are produced by the Sleep
            // Ritual feature only — users never hand-pick them here.
            for (final kind in BoltKind.values.where(
              (k) => k != BoltKind.dream && k != BoltKind.morningCharge,
            ))
              _Choice(
                label: kind.label,
                icon: kind.icon,
                active: _kind == kind,
                color: AetherColors.goldLight,
                onTap: () {
                  tap(context);
                  setState(() => _kind = kind);
                },
              ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionTitle('Theme'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final topic in BoltTopic.values)
              _Choice(
                label: topic.label,
                icon: topic.icon,
                active: _topic == topic,
                color: topic.color,
                onTap: () {
                  tap(context);
                  setState(() => _topic = topic);
                },
              ),
          ],
        ),
        const SizedBox(height: 18),
        const SectionTitle('Words'),
        const SizedBox(height: 10),
        TextField(
          controller: _text,
          minLines: 3,
          maxLines: 6,
          maxLength: 280,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            hintText: 'The line that changes your mood…',
            counterStyle: TextStyle(color: AetherColors.muted, fontSize: 11),
          ),
        ),
        if (_kind == BoltKind.quote) ...[
          const SizedBox(height: 10),
          TextField(
            controller: _author,
            onChanged: (_) => setState(() {}),
            maxLength: 40,
            decoration: const InputDecoration(
              hintText: 'Who said it? (optional)',
              counterText: '',
              prefixIcon: Icon(Icons.record_voice_over_rounded, color: AetherColors.muted),
            ),
          ),
        ],
        if (_kind == BoltKind.collage) ...[
          const SizedBox(height: 16),
          const SectionTitle('Collage words'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _word,
                  maxLength: 14,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addWord(),
                  decoration: const InputDecoration(
                    hintText: 'Add a word — CAPS shout, lowercase whispers',
                    counterText: '',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addWord,
                style: IconButton.styleFrom(backgroundColor: AetherColors.azure),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_words.isEmpty)
            const Text(
              'Up to 5 words. They get stacked into a painted collage.',
              style: TextStyle(fontSize: 12, color: AetherColors.muted),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final word in _words)
                  InputChip(
                    label: Text(word),
                    onDeleted: () => setState(() => _words.remove(word)),
                    backgroundColor: AetherColors.glassFill,
                    side: const BorderSide(color: AetherColors.glassStroke),
                    labelStyle: const TextStyle(color: AetherColors.ivory, fontSize: 12.5),
                    deleteIconColor: AetherColors.muted,
                  ),
              ],
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              const Text(
                'Palette',
                style: TextStyle(fontSize: 12.5, color: AetherColors.muted),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 34,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: CollagePalette.all.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final palette = CollagePalette.at(index);
                      final active = _palette == index;
                      return InkWell(
                        onTap: () => setState(() => _palette = index),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          width: 34,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(colors: palette.colors),
                            border: Border.all(
                              color: active ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),
        const SectionTitle('Attachments'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _AttachTile(
                icon: _imagePath == null ? Icons.add_photo_alternate_rounded : Icons.check_rounded,
                label: _imagePath == null ? 'Photo' : 'Photo added',
                active: _imagePath != null,
                onTap: _imagePath == null
                    ? _photoSheet
                    : () => setState(() => _imagePath = null),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _AttachTile(
                icon: _recording
                    ? Icons.stop_circle_rounded
                    : (_audioPath == null ? Icons.mic_rounded : Icons.check_rounded),
                label: _recording
                    ? 'Recording ${_recorded.inSeconds}s'
                    : (_audioPath == null ? 'Voice note' : 'Voice added'),
                active: _recording || _audioPath != null,
                color: _recording ? AetherColors.rose : null,
                onTap: _audioPath == null ? _toggleRecording : _dropAudio,
              ),
            ),
          ],
        ),
        if (_imagePath != null) ...[
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Image.file(
              File(_imagePath!),
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, _, _) => const SizedBox.shrink(),
            ),
          ),
        ],
        if (_audioPath != null) ...[
          const SizedBox(height: 12),
          VoiceNoteBar(path: _audioPath!, accent: _topic.color),
        ],
        const SizedBox(height: 22),
        const SectionTitle('Preview'),
        const SizedBox(height: 12),
        BoltTile(bolt: _preview),
        const SizedBox(height: 20),
        BoltButton(
          label: _busy ? 'Charging…' : 'Save to my collection',
          icon: Icons.bookmark_added_rounded,
          colors: const [AetherColors.gold, AetherColors.goldLight],
          onPressed: _busy ? null : () => _submit(publish: false),
        ),
      ],
    );
  }

  void _addWord() {
    final value = _word.text.trim();
    if (value.isEmpty || _words.length >= 5) return;
    setState(() {
      _words.add(value);
      _word.clear();
    });
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.label,
    required this.icon,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool active;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(30),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.8) : AetherColors.glassStroke,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? color : AetherColors.muted),
            const SizedBox(width: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: active ? color : AetherColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachTile extends StatelessWidget {
  const _AttachTile({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? (active ? AetherColors.mint : AetherColors.electric);
    return GlassPanel(
      onTap: onTap,
      radius: 20,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      fill: active ? tone.withValues(alpha: 0.14) : null,
      stroke: active ? tone.withValues(alpha: 0.6) : null,
      child: Column(
        children: [
          Icon(icon, color: tone, size: 22),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: active ? tone : AetherColors.ivory,
            ),
          ),
        ],
      ),
    );
  }
}
