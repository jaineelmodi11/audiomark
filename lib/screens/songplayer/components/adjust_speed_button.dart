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
  /// Snap an arbitrary speed to the nearest preset so the dropdown always has
  /// a matching value.
  double _nearestPreset(double speed) => list.reduce(
      (a, b) => (a - speed).abs() < (b - speed).abs() ? a : b);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Source the displayed value from the saved preference (read synchronously),
    // not from audioPlayer.speed which only updates after the async setSpeed()
    // resolves. This makes the label reflect the selection immediately and show
    // the restored speed when the player is reopened.
    final double current =
        _nearestPreset(PrefsService.instance.getSpeed(widget.songId));
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
        widget.audioPlayer.setSpeed(value);
        PrefsService.instance.setSpeed(widget.songId, value);
        setState(() {}); // rebuild so `current` re-reads the saved value
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
