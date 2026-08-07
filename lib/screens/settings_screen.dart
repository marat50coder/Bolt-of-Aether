import 'package:flutter/material.dart';

import '../core/app_palette.dart';
import '../core/app_scope.dart';
import '../core/models.dart';
import '../widgets/aether_background.dart';
import '../widgets/glass.dart';
import 'web_page_screen.dart';

const String kPrivacyPolicyUrl = 'https://boltofaether.com/privacy-policy.html';
const String kSupportUrl = 'https://boltofaether.com/support.html';
const String kAppVersion = '1.0.0';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);

    return Scaffold(
      body: AetherBackground(
        animate: state.motion,
        sparkCount: 16,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 18, 0),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.of(context).maybePop(),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: ShaderText(
                        'Settings',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.asset('assets/icon_small.png', height: 34),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
                  children: [
                    const SectionTitle('Profile'),
                    const SizedBox(height: 12),
                    GlassPanel(
                      radius: 22,
                      child: Row(
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            alignment: Alignment.center,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [AetherColors.azure, AetherColors.electric],
                              ),
                            ),
                            child: Text(
                              state.nickname.isEmpty
                                  ? '?'
                                  : state.nickname.substring(0, 1).toUpperCase(),
                              style: const TextStyle(
                                color: AetherColors.night,
                                fontWeight: FontWeight.w900,
                                fontSize: 19,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  state.nickname,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  '${state.saved.length} saved · ${state.myBolts.length} created · '
                                  '${state.streak} day streak',
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AetherColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Rename',
                            onPressed: () => _renameDialog(context, state.nickname),
                            icon: const Icon(Icons.edit_rounded,
                                size: 18, color: AetherColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const SectionTitle('Themes you follow'),
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Daily bolts and the deck are drawn from these.',
                        style: TextStyle(fontSize: 12.5, color: AetherColors.muted),
                      ),
                    ),
                    for (final topic in BoltTopic.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassPanel(
                          radius: 18,
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          onTap: () {
                            tap(context);
                            state.toggleTopic(topic);
                          },
                          child: Row(
                            children: [
                              Icon(topic.icon, size: 19, color: topic.color),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      topic.label,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 14.5,
                                      ),
                                    ),
                                    Text(
                                      topic.blurb,
                                      style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AetherColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: state.topics.contains(topic),
                                activeThumbColor: topic.color,
                                onChanged: (_) {
                                  tap(context);
                                  state.toggleTopic(topic);
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    const SectionTitle('Experience'),
                    const SizedBox(height: 12),
                    GlassPanel(
                      radius: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: state.haptics,
                            onChanged: state.setHaptics,
                            activeThumbColor: AetherColors.electric,
                            title: const Text('Haptic feedback',
                                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                            subtitle: const Text('Small buzz on swipes and taps',
                                style: TextStyle(fontSize: 11.5, color: AetherColors.muted)),
                          ),
                          const Divider(height: 1, color: AetherColors.glassStroke),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: state.motion,
                            onChanged: state.setMotion,
                            activeThumbColor: AetherColors.electric,
                            title: const Text('Animated background',
                                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                            subtitle: const Text('Turn off for a calmer, lighter screen',
                                style: TextStyle(fontSize: 11.5, color: AetherColors.muted)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const SectionTitle('Sleep ritual'),
                    const SizedBox(height: 6),
                    const Padding(
                      padding: EdgeInsets.only(bottom: 10),
                      child: Text(
                        'Fully manual, fully offline — no health data is ever read.',
                        style: TextStyle(fontSize: 12.5, color: AetherColors.muted),
                      ),
                    ),
                    GlassPanel(
                      radius: 22,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: state.morningChargeEnabled,
                            onChanged: state.setMorningChargeEnabled,
                            activeThumbColor: AetherColors.gold,
                            title: const Text('Morning Charge',
                                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                            subtitle: const Text('Word, quote and dream journal on first open',
                                style: TextStyle(fontSize: 11.5, color: AetherColors.muted)),
                          ),
                          const Divider(height: 1, color: AetherColors.glassStroke),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            value: state.eveningDischargeEnabled,
                            onChanged: state.setEveningDischargeEnabled,
                            activeThumbColor: AetherColors.moonViolet,
                            title: const Text('Evening Discharge',
                                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                            subtitle: const Text('Soft reminder banner on the Today screen',
                                style: TextStyle(fontSize: 11.5, color: AetherColors.muted)),
                          ),
                          const Divider(height: 1, color: AetherColors.glassStroke),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            enabled: state.eveningDischargeEnabled,
                            leading: const Icon(Icons.schedule_rounded, color: AetherColors.moonViolet),
                            title: const Text('Remind me at',
                                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                            subtitle: Text(
                              state.eveningReminderTime.format(context),
                              style: const TextStyle(fontSize: 11.5, color: AetherColors.muted),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded, color: AetherColors.muted),
                            onTap: () => _pickReminderTime(context, state.eveningReminderTime),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    const SectionTitle('About & legal'),
                    const SizedBox(height: 12),
                    _LinkRow(
                      icon: Icons.privacy_tip_rounded,
                      label: 'Privacy Policy',
                      onTap: () => _openWeb(context, 'Privacy Policy', kPrivacyPolicyUrl),
                    ),
                    const SizedBox(height: 10),
                    _LinkRow(
                      icon: Icons.support_agent_rounded,
                      label: 'Support',
                      onTap: () => _openWeb(context, 'Support', kSupportUrl),
                    ),
                    const SizedBox(height: 10),
                    _LinkRow(
                      icon: Icons.delete_sweep_rounded,
                      label: 'Reset all data',
                      tone: AetherColors.rose,
                      onTap: () => _resetDialog(context),
                    ),
                    const SizedBox(height: 22),
                    Center(
                      child: Column(
                        children: [
                          Image.asset('assets/Game_Name.webp', height: 84),
                          const SizedBox(height: 6),
                          const Text(
                            'Bolt of Aether',
                            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                          const SizedBox(height: 2),
                          const Text(
                            'Version $kAppVersion · com.boltaether.boltaethergame',
                            style: TextStyle(fontSize: 11, color: AetherColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openWeb(BuildContext context, String title, String url) {
    tap(context);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => WebPageScreen(title: title, url: url)),
    );
  }

  Future<void> _pickReminderTime(BuildContext context, TimeOfDay current) async {
    tap(context);
    final state = AppScope.read(context);
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: 'Evening Discharge reminder',
    );
    if (picked != null) await state.setEveningReminderTime(picked);
  }

  Future<void> _renameDialog(BuildContext context, String current) async {
    final controller = TextEditingController(text: current);
    final state = AppScope.read(context);
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AetherColors.deep,
        title: const Text('Your name', style: TextStyle(fontSize: 18)),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 22,
          decoration: const InputDecoration(counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null) await state.setNickname(value);
  }

  Future<void> _resetDialog(BuildContext context) async {
    final state = AppScope.read(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AetherColors.deep,
        title: const Text('Reset everything?', style: TextStyle(fontSize: 18)),
        content: const Text(
          'Saved bolts, your creations, posts and the streak will be erased. '
          'This cannot be undone.',
          style: TextStyle(fontSize: 13.5, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep it'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AetherColors.rose),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await state.resetEverything();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All local data cleared')),
    );
  }
}

class _LinkRow extends StatelessWidget {
  const _LinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.tone = AetherColors.electric,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      onTap: onTap,
      radius: 20,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: tone),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AetherColors.muted),
        ],
      ),
    );
  }
}
