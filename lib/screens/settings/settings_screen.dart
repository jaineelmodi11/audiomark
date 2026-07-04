import 'package:flutter/material.dart';
import 'package:songhut/constants.dart';
import 'package:songhut/services/prefs_service.dart';

/// Settings: practice preferences plus About/Tips.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final prefs = PrefsService.instance;

    Widget sectionLabel(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text(
            text,
            style: TextStyle(
              color: scheme.primary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.0,
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          sectionLabel('PRACTICE'),
          SwitchListTile(
            secondary: const Icon(Icons.av_timer_rounded),
            title: const Text('Count-in before play'),
            subtitle: const Text('3 beeps before playback starts'),
            value: prefs.countInEnabled,
            onChanged: (v) async {
              await prefs.setCountInEnabled(v);
              setState(() {});
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.light_mode_outlined),
            title: const Text('Keep screen awake'),
            subtitle: const Text("Don't sleep while music is playing"),
            value: prefs.keepAwakeEnabled,
            onChanged: (v) async {
              await prefs.setKeepAwakeEnabled(v);
              setState(() {});
            },
          ),
          const Divider(height: 24),
          sectionLabel('ABOUT'),
          const ListTile(
            leading: Icon(Icons.music_note_rounded),
            title: Text('AudioMark'),
            subtitle: Text('A music player optimized for dancers'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text(kAppVersion),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () => _showPrivacyInfo(context),
          ),
          const Divider(height: 24),
          sectionLabel('TIPS'),
          const ListTile(
            leading: Icon(Icons.repeat_rounded),
            title: Text('Loop a section'),
            subtitle: Text(
                'On the player, drag the two handles to set a start and end point, then turn on loop.'),
          ),
          const ListTile(
            leading: Icon(Icons.bookmark_border_rounded),
            title: Text('Save practice sections'),
            subtitle: Text(
                'Tap the bookmark on the player to name the current range — Chorus, Drop — and jump back to it any time.'),
          ),
          const ListTile(
            leading: Icon(Icons.speed_rounded),
            title: Text('Slow it down'),
            subtitle: Text(
                'Use the speed control to practice tricky choreography at a slower tempo.'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showPrivacyInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const Text(
          'AudioMark plays audio files stored on your device. It does not collect '
          'or upload your personal data. Music library access is used only to list '
          'and play songs on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
