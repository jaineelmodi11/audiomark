import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:songhut/constants.dart';

const List<double> list = <double>[0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

class AdjustSpeed extends StatefulWidget {
  const AdjustSpeed({super.key, required this.audioPlayer});
  final AudioPlayer audioPlayer;
  @override
  State<AdjustSpeed> createState() => _AdjustSpeedState();
}

class _AdjustSpeedState extends State<AdjustSpeed> {
  double dropdownValue = list[3];

  @override
  Widget build(BuildContext context) {
    return DropdownButton<double>(
      iconSize: 0.0,
      value: widget.audioPlayer.speed,
      elevation: 16,
      focusColor: kPrimaryColor,
      onChanged: (double? value) {
        setState(() {
          dropdownValue = value!;
          widget.audioPlayer.setSpeed(dropdownValue);
        });
      },
      items: list.map<DropdownMenuItem<double>>((double value) {
        return DropdownMenuItem<double>(
          value: value,
          child: Text(
            '${value.toString()}x',
            style: const TextStyle(color: Colors.black),
          ),
        );
      }).toList(),
    );
  }
}
