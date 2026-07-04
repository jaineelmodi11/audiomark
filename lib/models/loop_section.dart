/// A named practice section of a song ("Chorus", "Drop", …) that dancers save
/// and jump back to. Stored per song in shared preferences as JSON.
class LoopSection {
  const LoopSection({
    required this.name,
    required this.startSec,
    required this.endSec,
  });

  final String name;
  final int startSec;
  final int endSec;

  Map<String, dynamic> toJson() =>
      {'name': name, 'start': startSec, 'end': endSec};

  factory LoopSection.fromJson(Map<String, dynamic> json) => LoopSection(
        name: (json['name'] as String?) ?? 'Section',
        startSec: (json['start'] as num?)?.toInt() ?? 0,
        endSec: (json['end'] as num?)?.toInt() ?? 0,
      );
}
