import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:section_loop/section_loop.dart' as sl;
import 'package:songhut/services/prefs_service.dart';

/// Owns the app's single [AudioPlayer], the current queue, and the
/// section-loop engine.
///
/// Living here (instead of in the player screen) means the loop keeps
/// enforcing, per-song speed keeps restoring and recents keep recording even
/// when the player screen is closed or the phone is locked — essential for
/// dancers practising with the screen off.
class PlayerHost {
  PlayerHost._();
  static final PlayerHost instance = PlayerHost._();

  final AudioPlayer player = AudioPlayer();

  /// Stable stream instances. just_audio's stream getters build a NEW derived
  /// stream object per access; passing those straight into a StreamBuilder
  /// makes it unsubscribe/resubscribe every rebuild, and the replay-on-listen
  /// then triggers another rebuild — an infinite loop. Always use these.
  late final Stream<int?> currentIndexStream = player.currentIndexStream;
  late final Stream<PlayerState> playerStateStream = player.playerStateStream;
  late final Stream<Duration> positionStream = player.positionStream;
  late final Stream<Duration?> durationStream = player.durationStream;

  /// Current queue metadata (parallel to the player's audio sources).
  /// Listened to by the mini-player so it can appear/disappear.
  final ValueNotifier<List<SongModel>> queueListenable =
      ValueNotifier(const []);

  List<SongModel> get queue => queueListenable.value;
  bool get hasQueue => queue.isNotEmpty;

  /// Section-loop boundaries (seconds) for the current song. Mirrors the
  /// player screen's range slider and each song's saved loop.
  double _loopStartSec = 0;
  double _loopEndSec = double.infinity;

  bool _listenersReady = false;
  bool _settling = false; // ignore stale index emissions during setQueue
  int _expectedInitialIndex = 0;
  /// Section looping lives in the `section_loop` package, which was extracted
  /// from this file. It owns the seek guard and the whole-track rule, both of
  /// which are covered by tests there.
  late final sl.SectionLoopEngine _loop = sl.SectionLoopEngine(
    onSeek: player.seek,
    onPause: player.pause,
    onPlay: player.play,
  );
  int? _lastHandledIndex; // makes _onIndexChanged idempotent per index

  SongModel? get currentSong {
    final i = player.currentIndex;
    if (i == null || i < 0 || i >= queue.length) return null;
    return queue[i];
  }

  /// True when [songs] is the queue already loaded in the player, so callers
  /// can attach UI to ongoing playback instead of restarting it.
  bool isCurrentQueue(List<SongModel> songs) {
    if (songs.length != queue.length) return false;
    for (int i = 0; i < songs.length; i++) {
      if (songs[i].id != queue[i].id) return false;
    }
    return true;
  }

  /// Loads [songs] into the player starting at [initialIndex] and applies the
  /// initial song's saved speed and loop. Does not start playback.
  Future<void> setQueue(List<SongModel> songs, int initialIndex) async {
    _ensureListeners();
    queueListenable.value = List.unmodifiable(songs);
    _settling = true;
    _expectedInitialIndex = initialIndex;

    final sources = songs.map(_sourceFor).toList();
    // ConcatenatingAudioSource is deprecated in just_audio 0.10 (use
    // setAudioSources); migration deferred — the shared-player queue/index
    // logic is verified working and sensitive to change.
    await player.setAudioSource(
      // ignore: deprecated_member_use
      ConcatenatingAudioSource(children: sources),
      initialIndex: initialIndex,
    );

    _applySavedSettingsFor(songs[initialIndex].id);
    await PrefsService.instance.addRecent(songs[initialIndex].id);
  }

  AudioSource _sourceFor(SongModel song) {
    final artist = song.artist;
    return AudioSource.uri(
      Uri.parse(song.uri!),
      // Tag drives the lock-screen / notification controls.
      tag: MediaItem(
        id: song.id.toString(),
        title: song.displayNameWOExt,
        artist: (artist == null || artist == '<unknown>')
            ? 'Unknown Artist'
            : artist,
        album: 'AudioMark',
      ),
    );
  }

  /// Called by the player screen whenever the loop range changes.
  void setSectionLoop(double startSec, double endSec) {
    _loopStartSec = startSec;
    _loopEndSec = endSec;
  }

  /// Whether [startSec, endSec] is a strict sub-range of the track — i.e. a
  /// deliberate practice section. A full-track range means "no section": the
  /// track should end naturally so the queue can auto-advance.
  @visibleForTesting
  static bool isSubRange(double startSec, double endSec, double? durationSec) {
    if (durationSec == null || durationSec <= 0) return false;
    if (endSec <= startSec || startSec < 0) return false;
    return _rangeProbe.isSubRange(
      sl.LoopSection(
        name: 'range',
        start: _seconds(startSec),
        end: _seconds(endSec),
      ),
      _seconds(durationSec),
    );
  }

  /// Engine used only to answer [isSubRange]; its callbacks never fire.
  static final sl.SectionLoopEngine _rangeProbe = sl.SectionLoopEngine(
    onSeek: (_) async {},
    onPause: () async {},
  );

  static Duration _seconds(double value) =>
      Duration(milliseconds: (value * 1000).round());

  void _ensureListeners() {
    if (_listenersReady) return;
    _listenersReady = true;

    positionStream.listen(_onPosition);
    currentIndexStream.listen(_onIndexChanged);
  }

  void _onPosition(Duration position) {
    // Loop on jumps back to the section start; loop off plays the section once
    // and holds at the end. The engine handles the seek guard, and treats a
    // whole-track range as no section so the queue still auto-advances.
    _loop
      ..behavior = player.loopMode == LoopMode.all
          ? sl.SectionEndBehavior.loop
          : sl.SectionEndBehavior.pauseAtEnd
      ..section = _activeSection();
    _loop.handlePosition(
      position,
      trackDuration: player.duration,
      isPlaying: player.playing,
    );
  }

  /// The current range as the package models it, or null when no usable
  /// section is set. [sl.LoopSection] rejects inverted and infinite ranges,
  /// and `_loopEndSec` is infinity until a song sets its own.
  sl.LoopSection? _activeSection() {
    if (!_loopEndSec.isFinite || _loopEndSec <= _loopStartSec) return null;
    if (_loopStartSec < 0) return null;
    return sl.LoopSection(
      name: 'Section',
      start: _seconds(_loopStartSec),
      end: _seconds(_loopEndSec),
    );
  }

  void _onIndexChanged(int? index) {
    if (index == null || index < 0 || index >= queue.length) return;
    if (_settling) {
      // just_audio replays a transient/stale index while setAudioSource
      // applies initialIndex; wait for it to settle on the requested song
      // (whose settings setQueue already applied).
      if (index == _expectedInitialIndex) {
        _settling = false;
        _lastHandledIndex = index;
      }
      return;
    }
    if (index == _lastHandledIndex) return; // replayed/duplicate emission
    _lastHandledIndex = index;
    final id = queue[index].id;
    PrefsService.instance.addRecent(id);
    // Deferred: mutating the player from inside its own index-stream callback
    // re-enters the platform channel and crashes.
    Future.microtask(() => _applySavedSettingsFor(id));
  }

  void _applySavedSettingsFor(int id) {
    final savedSpeed = PrefsService.instance.getSpeed(id);
    // Only touch the player when the value actually changes — setSpeed emits
    // a playback event, and blind re-sets can feed event→handler cycles.
    if ((player.speed - savedSpeed).abs() > 0.001) {
      player.setSpeed(savedSpeed);
    }
    final saved = PrefsService.instance.getLoop(id);
    if (saved != null) {
      _loopStartSec = saved[0].toDouble();
      _loopEndSec = saved[1].toDouble();
    } else {
      _loopStartSec = 0;
      _loopEndSec = double.infinity;
    }
  }
}
