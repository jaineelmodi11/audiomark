import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:songhut/services/prefs_service.dart';

const List<double> list = <double>[0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

class AdjustSpeed extends StatefulWidget {
  const AdjustSpeed({super.key, required this.audioPlayer, required this.songId});
  final AudioPlayer audioPlayer;
  final int songId;
  @override
  State<AdjustSpeed> createState() => _AdjustSpeedState();
}

class _AdjustSpeedState extends State<AdjustSpeed> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Snap the player's current speed to the nearest preset so the dropdown
    // always has a matching value.
    final double current = list.reduce((a, b) =>
        (a - widget.audioPlayer.speed).abs() <
                (b - widget.audioPlayer.speed).abs()
            ? a
            : b);
    return DropdownButton<double>(
      iconSize: 0.0,
      value: current,
      elevation: 16,
      borderRadius: BorderRadius.circular(12),
      style: TextStyle(
        color: scheme.onSurface,
        fontWeight: FontWeight.w500,
        fontSize: 16,
      ),
      onChanged: (double? value) {
        if (value == null) return;
        setState(() => widget.audioPlayer.setSpeed(value));
        PrefsService.instance.setSpeed(widget.songId, value);
      },
      items: list.map<DropdownMenuItem<double>>((double value) {
        return DropdownMenuItem<double>(
          value: value,
          child: Text('${value}x'),
        );
      }).toList(),
    );
  }
}
