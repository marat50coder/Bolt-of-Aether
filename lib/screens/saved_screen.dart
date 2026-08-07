import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_palette.dart';
import '../core/app_scope.dart';
import '../core/models.dart';
import '../core/sleep_utils.dart';
import '../widgets/bolt_card.dart';
import '../widgets/glass.dart';
import 'home_shell.dart';

/// Everything the user swiped right on, plus their own creations and dreams.
class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  BoltTopic? _filter;
  bool _onlyMine = false;
  bool _dreamsMode = false;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    var items = state.savedByTopic(_filter);
    if (_onlyMine) items = items.where((b) => b.isMine).toList();
    final dreams = state.dreamEntries;

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 120),
      children: [
        Row(
          children: [
            Expanded(
              child: ShaderText(
                'Collection',
                style: const TextStyle(
                  fontSize: 27,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            AetherTag(
              label: _dreamsMode ? '${dreams.length} dreams' : '${state.saved.length} bolts',
              icon: _dreamsMode ? Icons.nightlight_round : Icons.bolt_rounded,
              color: _dreamsMode ? AetherColors.violet : AetherColors.goldLight,
              dense: true,
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Your charged bolts live here, offline and yours.',
          style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.68)),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 34,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Toggle(
                  label: 'All themes',
                  icon: Icons.blur_on_rounded,
                  active: !_dreamsMode && _filter == null,
                  color: AetherColors.electric,
                  onTap: () => setState(() {
                    _dreamsMode = false;
                    _filter = null;
                  }),
                ),
              ),
              for (final topic in BoltTopic.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Toggle(
                    label: topic.label,
                    icon: topic.icon,
                    active: !_dreamsMode && _filter == topic,
                    color: topic.color,
                    onTap: () => setState(() {
                      _dreamsMode = false;
                      _filter = topic;
                    }),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Toggle(
                  label: 'Mine only',
                  icon: Icons.person_rounded,
                  active: !_dreamsMode && _onlyMine,
                  color: AetherColors.gold,
                  onTap: () => setState(() {
                    _dreamsMode = false;
                    _onlyMine = !_onlyMine;
                  }),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _Toggle(
                  label: 'Dreams',
                  icon: Icons.nightlight_round,
                  active: _dreamsMode,
                  color: AetherColors.violet,
                  onTap: () => setState(() => _dreamsMode = !_dreamsMode),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_dreamsMode)
          if (dreams.isEmpty)
            const _EmptyDreams()
          else
            for (final dream in dreams)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: _DreamTile(dream: dream),
              )
        else if (items.isEmpty)
          _EmptyCollection(
            onDiscover: () => HomeNav.jump(context, 1),
            onCreate: () => HomeNav.jump(context, 2),
          )
        else
          for (final bolt in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: BoltTile(
                bolt: bolt,
                trailing: Row(
                  children: [
                    IconButton(
                      tooltip: 'Copy',
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        tap(context);
                        Clipboard.setData(ClipboardData(text: bolt.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard')),
                        );
                      },
                      icon: const Icon(Icons.copy_rounded, color: AetherColors.muted),
                    ),
                    IconButton(
                      tooltip: 'Remove',
                      iconSize: 18,
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        tap(context);
                        state.removeSaved(bolt.id);
                      },
                      icon: const Icon(Icons.bookmark_remove_rounded,
                          color: AetherColors.muted),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _DreamTile extends StatelessWidget {
  const _DreamTile({required this.dream});

  final DreamEntry dream;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 24,
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.nightlight_round, size: 16, color: AetherColors.violet),
              const SizedBox(width: 6),
              Text(
                dream.dateKey,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
              ),
              if (dream.mood != null) ...[
                const SizedBox(width: 8),
                Icon(dream.mood!.icon, size: 15, color: AetherColors.muted),
              ],
              if (dream.sleepDurationMinutes != null) ...[
                const SizedBox(width: 8),
                Text(
                  '~${formatSleepDuration(Duration(minutes: dream.sleepDurationMinutes!))}',
                  style: const TextStyle(fontSize: 11.5, color: AetherColors.muted),
                ),
              ],
              const Spacer(),
              IconButton(
                tooltip: 'Delete',
                iconSize: 18,
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  tap(context);
                  AppScope.read(context).deleteDream(dream.id);
                },
                icon: const Icon(Icons.delete_outline_rounded, color: AetherColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            dream.text.isEmpty ? 'No details written down.' : dream.text,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.4,
              fontStyle: dream.text.isEmpty ? FontStyle.italic : FontStyle.normal,
              color: dream.text.isEmpty
                  ? AetherColors.muted
                  : AetherColors.ivory,
            ),
          ),
          if (dream.tags.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in dream.tags)
                  AetherTag(label: tag.label, icon: tag.icon, color: AetherColors.violet, dense: true),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyDreams extends StatelessWidget {
  const _EmptyDreams();

  @override
  Widget build(BuildContext context) {
    return const GlassPanel(
      radius: 26,
      padding: EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      child: Column(
        children: [
          Icon(Icons.nightlight_round, size: 42, color: AetherColors.muted),
          SizedBox(height: 14),
          Text(
            'No dreams logged yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 6),
          Text(
            'The Dream Journal shows up each morning after you charge.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AetherColors.muted),
          ),
        ],
      ),
    );
  }
}

class _EmptyCollection extends StatelessWidget {
  const _EmptyCollection({required this.onDiscover, required this.onCreate});

  final VoidCallback onDiscover;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      radius: 26,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 20),
      child: Column(
        children: [
          const Icon(Icons.bookmark_border_rounded, size: 42, color: AetherColors.muted),
          const SizedBox(height: 14),
          const Text(
            'No bolts kept yet',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Swipe right in Discover, or create your own bolt.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AetherColors.muted),
          ),
          const SizedBox(height: 18),
          GhostButton(
            label: 'Open the deck',
            icon: Icons.style_rounded,
            color: AetherColors.electric,
            onPressed: onDiscover,
          ),
          const SizedBox(height: 10),
          GhostButton(
            label: 'Create your own',
            icon: Icons.add_rounded,
            color: AetherColors.goldLight,
            onPressed: onCreate,
          ),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
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
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
        decoration: BoxDecoration(
          color: active ? color.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: active ? color.withValues(alpha: 0.75) : AetherColors.glassStroke,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 14, color: active ? color : AetherColors.muted),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
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
