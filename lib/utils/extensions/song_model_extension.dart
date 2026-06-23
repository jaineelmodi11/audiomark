import 'package:on_audio_query/on_audio_query.dart';

extension ExtendedSongModel on SongModel {
  String get additionalSongInfo {
    String artistInfo = artist.toString();
    String songTime = _millisToMinutesAndSeconds(duration);
    String artistName =
        artistInfo == "<unknown>" ? "Unknown Artist" : artistInfo;
    return "$artistName\t\t$songTime";
  }

  String _millisToMinutesAndSeconds(int? millis) {
    final ms = millis ?? 0;
    int minutes = ((ms / 1000) / 60).toInt();
    int seconds = ((ms / 1000) % 60).toInt();
    return "$minutes:$seconds";
  }
}
