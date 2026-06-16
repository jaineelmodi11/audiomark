import 'package:flutter/material.dart';

/// A simple Settings / About screen. Replaces the old "Coming Soon" placeholder
/// that the player and tile menus used to dead-end into.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              'ABOUT',
              style: TextStyle(
                color: scheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.music_note_rounded),
            title: Text('AudioMark'),
            subtitle: Text('A music player optimized for dancers'),
          ),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Privacy Policy'),
            onTap: () => _showPrivacyInfo(context),
          ),
          const Divider(height: 24),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'TIPS',
              style: TextStyle(
                color: scheme.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.0,
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.repeat_rounded),
            title: Text('Loop a section'),
            subtitle: Text(
                'On the player, drag the two outer handles to set a start and end point, then turn on loop.'),
          ),
          const ListTile(
            leading: Icon(Icons.speed_rounded),
            title: Text('Slow it down'),
            subtitle: Text(
                'Use the speed control to practice tricky choreography at a slower tempo.'),
          ),
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
