import 'dart:convert';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-managed audio library for iOS (and any platform without a shared
/// MediaStore). Imported files are copied into the app's documents directory
/// and indexed locally; the index is exposed as [SongModel]s so the existing
/// (on_audio_query–based) UI and player work unchanged. Playback uses the
/// file:// `uri`, which just_audio plays directly.
class ImportedLibrary {
  ImportedLibrary._();
  static final ImportedLibrary instance = ImportedLibrary._();

  static const _indexKey = 'imported_songs_index';

  Future<Directory> _mediaDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'imported_audio'));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<List<Map<String, dynamic>>> _readIndex() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_indexKey);
    if (raw == null) return <Map<String, dynamic>>[];
    return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
  }

  Future<void> _writeIndex(List<Map<String, dynamic>> index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_indexKey, jsonEncode(index));
  }

  /// A stable, positive id derived from the file path so favourites / recents /
  /// per-song settings (keyed by int id) persist across launches.
  int _idFor(String path) => path.hashCode & 0x7fffffff;

  SongModel _toSongModel(Map<String, dynamic> e) {
    final path = e['path'] as String;
    return SongModel(<String, dynamic>{
      '_id': e['id'],
      '_data': path,
      '_uri': Uri.file(path).toString(),
      '_display_name': e['title'],
      '_display_name_wo_ext': e['title'],
      '_size': e['size'] ?? 0,
      'title': e['title'],
      'artist': e['artist'] ?? 'Imported',
      'duration': e['duration'] ?? 0,
      'date_added': e['dateAdded'],
      'is_music': true,
    });
  }

  /// Imported songs, most-recent first. Drops entries whose backing file is
  /// gone so a stale index never produces unplayable rows.
  Future<List<SongModel>> songs() async {
    final index = await _readIndex();
    final present =
        index.where((e) => File(e['path'] as String).existsSync()).toList();
    if (present.length != index.length) await _writeIndex(present);
    return present.map(_toSongModel).toList();
  }

  /// Copies [srcPath] into app storage, probes its duration, indexes it and
  /// returns the resulting [SongModel]. Re-importing the same name replaces the
  /// previous entry.
  Future<SongModel?> importFile(String srcPath, String name) async {
    final dir = await _mediaDir();
    final dest = p.join(dir.path, name);
    await File(srcPath).copy(dest);

    int duration = 0;
    final probe = AudioPlayer();
    try {
      final d = await probe.setFilePath(dest);
      duration = d?.inMilliseconds ?? 0;
    } catch (_) {
      // Non-fatal: a 0 duration just shows 0:00 until played.
    } finally {
      await probe.dispose();
    }

    final entry = <String, dynamic>{
      'id': _idFor(dest),
      'path': dest,
      'title': p.basenameWithoutExtension(name),
      'artist': 'Imported',
      'duration': duration,
      'size': await File(dest).length(),
      'dateAdded': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    final index = await _readIndex();
    index.removeWhere((e) => e['id'] == entry['id']);
    index.insert(0, entry);
    await _writeIndex(index);
    return _toSongModel(entry);
  }
}
