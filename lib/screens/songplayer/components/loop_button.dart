import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class LoopButton extends StatefulWidget {
  const LoopButton({super.key, required this.audioPlayer});
  final AudioPlayer audioPlayer;
  @override
  State<LoopButton> createState() => _LoopButtonState();
}

class _LoopButtonState extends State<LoopButton> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool on = widget.audioPlayer.loopMode != LoopMode.off;
    return IconButton(
      tooltip: 'Loop the selected section',
      onPressed: () {
        widget.audioPlayer
            .setLoopMode(on ? LoopMode.off : LoopMode.all);
        setState(() {});
      },
      icon: Icon(
        Icons.repeat_rounded,
        color: on ? scheme.primary : scheme.onSurfaceVariant,
        size: 24.0,
      ),
    );
  }
}
