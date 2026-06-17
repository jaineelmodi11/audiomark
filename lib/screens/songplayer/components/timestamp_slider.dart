import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class TimeStampSlider extends StatefulWidget {
  const TimeStampSlider({
    super.key,
    required this.audioPlayer,
    required this.duration,
  });
  final AudioPlayer audioPlayer;
  final double duration;

  @override
  State<TimeStampSlider> createState() => _TimestampSliderState();
}

class _TimestampSliderState extends State<TimeStampSlider> {
  // RangeValues _currentRangeValues = RangeValues(0.0, widget.duration);
  // RangeLabels _currentRangeLabels = RangeLabels("0", "100");
  @override
  Widget build(BuildContext context) {
    RangeValues currentRangeValues = RangeValues(0.0, widget.duration);
    RangeLabels currentRangeLabels =
        RangeLabels("0", widget.duration.toString());
    return RangeSlider(
      values: currentRangeValues,
      min: 0.0,
      max: widget.duration,
      labels: currentRangeLabels,
      onChanged: (RangeValues value) {
        setState(() {
          currentRangeValues = RangeValues(value.start, value.end);
          currentRangeLabels = RangeLabels(value.start.toString().split(".")[0],
              value.end.toString().split(".")[0]);
        });
      },
    );
  }
}
