import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class ShuffleButton extends StatefulWidget {
  const ShuffleButton({super.key, required this.audioPlayer});
  final AudioPlayer audioPlayer;
  @override
  State<ShuffleButton> createState() => _ShuffleButtonState();
}

class _ShuffleButtonState extends State<ShuffleButton> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool on = widget.audioPlayer.shuffleModeEnabled;
    return IconButton(
      tooltip: 'Shuffle',
      onPressed: () {
        widget.audioPlayer.setShuffleModeEnabled(!on);
        setState(() {});
      },
      icon: Icon(
        Icons.shuffle_rounded,
        color: on ? scheme.primary : scheme.onSurfaceVariant,
        size: 24.0,
      ),
    );
  }
}
