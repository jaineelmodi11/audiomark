import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:songhut/models/loop_section.dart';

/// Lightweight local persistence for the things the app should remember across
/// launches: favourites, recently played, and each song's saved loop section
/// and playback speed (handy for dancers reopening a practice track).
class PrefsService {
  PrefsService._();
  static final PrefsService instance = PrefsService._();

  late SharedPreferences _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // ---- Favourites -----------------------------------------------------------

  Set<int> get favorites =>
      (_prefs.getStringList('favorites') ?? const [])
          .map(int.parse)
          .toSet();

  bool isFavorite(int id) => favorites.contains(id);

  Future<void> toggleFavorite(int id) async {
    final favs = favorites;
    if (!favs.add(id)) favs.remove(id); // add() is false when already present
    await _prefs.setStringList(
        'favorites', favs.map((e) => e.toString()).toList());
  }

  // ---- Recently played (most recent first, capped) --------------------------

  List<int> get recentIds =>
      (_prefs.getStringList('recents') ?? const []).map(int.parse).toList();

  Future<void> addRecent(int id) async {
    final recents = recentIds..remove(id);
    recents.insert(0, id);
    if (recents.length > 20) recents.removeRange(20, recents.length);
    await _prefs.setStringList(
        'recents', recents.map((e) => e.toString()).toList());
  }

  // ---- Per-song saved speed -------------------------------------------------

  double getSpeed(int id) => _prefs.getDouble('speed_$id') ?? 1.0;

  Future<void> setSpeed(int id, double value) =>
      _prefs.setDouble('speed_$id', value);

  // ---- Per-song saved loop section (seconds) --------------------------------

  /// Returns [startSec, endSec] or null if nothing saved for this song.
  List<int>? getLoop(int id) {
    final start = _prefs.getInt('loopStart_$id');
    final end = _prefs.getInt('loopEnd_$id');
    if (start == null || end == null) return null;
    return [start, end];
  }

  Future<void> setLoop(int id, int startSec, int endSec) async {
    await _prefs.setInt('loopStart_$id', startSec);
    await _prefs.setInt('loopEnd_$id', endSec);
  }

  Future<void> clearLoop(int id) async {
    await _prefs.remove('loopStart_$id');
    await _prefs.remove('loopEnd_$id');
  }

  // ---- Named loop sections per song ("Chorus", "Drop", …) --------------------

  List<LoopSection> getLoopSections(int id) {
    final raw = _prefs.getString('sections_$id');
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(LoopSection.fromJson)
          .toList();
    } catch (_) {
      return const []; // corrupt entry — treat as none rather than crash
    }
  }

  Future<void> setLoopSections(int id, List<LoopSection> sections) =>
      _prefs.setString(
          'sections_$id', jsonEncode(sections.map((s) => s.toJson()).toList()));

  // ---- Count-in (global): 3 beeps before playback starts --------------------

  bool get countInEnabled => _prefs.getBool('count_in') ?? false;

  Future<void> setCountInEnabled(bool value) =>
      _prefs.setBool('count_in', value);

  // ---- Keep screen awake while playing (global, default on) -----------------

  bool get keepAwakeEnabled => _prefs.getBool('keep_awake') ?? true;

  Future<void> setKeepAwakeEnabled(bool value) =>
      _prefs.setBool('keep_awake', value);

  // ---- Per-song tempo for the 8-count display -------------------------------

  /// Beats per minute, or 0 when the tempo hasn't been set for this song.
  double getBpm(int id) => _prefs.getDouble('bpm_$id') ?? 0;

  /// Playback position (ms) of the downbeat — where the "1" of the 8-count
  /// falls — so counts line up with the music.
  int getBeatAnchorMs(int id) => _prefs.getInt('beatAnchor_$id') ?? 0;

  Future<void> setTempo(int id, double bpm, int anchorMs) async {
    await _prefs.setDouble('bpm_$id', bpm);
    await _prefs.setInt('beatAnchor_$id', anchorMs);
  }

  Future<void> clearTempo(int id) async {
    await _prefs.remove('bpm_$id');
    await _prefs.remove('beatAnchor_$id');
  }
}
