import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:songhut/services/prefs_service.dart';

/// Tappable playback-speed control. Shows the current speed inline and opens a
/// fine-grained slider (0.05 steps) + quick presets — much finer than the old
/// 0.25-step dropdown, which dancers found too coarse for dialling in a tempo.
class AdjustSpeed extends StatefulWidget {
  const AdjustSpeed(
      {super.key, required this.audioPlayer, required this.songId});
  final AudioPlayer audioPlayer;
  final int songId;
  @override
  State<AdjustSpeed> createState() => _AdjustSpeedState();
}

class _AdjustSpeedState extends State<AdjustSpeed> {
  static const double _min = 0.25;
  static const double _max = 2.0;
  static const double _step = 0.05;

  double get _speed => PrefsService.instance.getSpeed(widget.songId);

  String _fmt(double v) {
    var s = v.toStringAsFixed(2);
    if (s.endsWith('0')) s = s.substring(0, s.length - 1); // 1.50 -> 1.5
    return '${s}x';
  }

  void _apply(double value) {
    // Snap to the nearest step so the label and player stay tidy.
    final v = ((value.clamp(_min, _max)) / _step).round() * _step;
    final snapped = (v * 100).round() / 100;
    widget.audioPlayer.setSpeed(snapped);
    PrefsService.instance.setSpeed(widget.songId, snapped);
    setState(() {});
  }

  void _openSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final scheme = Theme.of(ctx).colorScheme;
          final speed = _speed.clamp(_min, _max);
          void set(double v) {
            _apply(v);
            setSheet(() {});
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Playback speed',
                        style: TextStyle(
                            color: scheme.onSurfaceVariant, fontSize: 13)),
                    if (speed != 1.0)
                      TextButton(
                        onPressed: () => set(1.0),
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero, minimumSize: Size.zero),
                        child: const Text('Reset'),
                      ),
                  ],
                ),
                Center(
                  child: Text(_fmt(speed),
                      style: TextStyle(
                          color: scheme.primary,
                          fontSize: 34,
                          fontWeight: FontWeight.bold)),
                ),
                Slider(
                  min: _min,
                  max: _max,
                  divisions: ((_max - _min) / _step).round(),
                  value: speed,
                  label: _fmt(speed),
                  onChanged: set,
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: const [0.5, 0.75, 1.0, 1.25, 1.5]
                      .map<Widget>((p) => ActionChip(
                            label: Text(_fmt(p)),
                            onPressed: () => set(p),
                          ))
                      .toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TextButton(
      onPressed: _openSheet,
      style: TextButton.styleFrom(
        foregroundColor: scheme.onSurface,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(_fmt(_speed),
          style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
    );
  }
}
