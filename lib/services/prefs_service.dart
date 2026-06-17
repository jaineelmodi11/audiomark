import 'package:shared_preferences/shared_preferences.dart';

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
}
