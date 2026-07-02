import 'dart:async';
import 'dart:ui' as ui;

import 'package:audioplayers/audioplayers.dart' as beeper;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:songhut/models/loop_section.dart';
import 'package:songhut/screens/songplayer/components/adjust_speed_button.dart';
import 'package:songhut/screens/songplayer/components/favorite_button.dart';
import 'package:songhut/screens/songplayer/components/loop_button.dart';
import 'package:songhut/screens/songplayer/components/loop_sections_sheet.dart';
import 'package:songhut/screens/songplayer/components/shuffle_button.dart';
import 'package:songhut/screens/settings/settings_screen.dart';
import 'package:songhut/services/player_host.dart';
import 'package:songhut/services/prefs_service.dart';
import 'package:songhut/utils/song_color.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../provider/song_model_provider.dart';

/// Opens the player with the slide-up transition. With [attach] the screen
/// binds to ongoing playback (mini-player tap) instead of restarting the queue.
Future<void> openSongPlayer(
  BuildContext context, {
  required List<SongModel> songs,
  required int index,
  bool attach = false,
  bool shuffle = false,
}) {
  context.read<SongModelProvider>().setId(songs[index].id);
  return Navigator.push(
    context,
    PageRouteBuilder(
      transitionDuration: const Duration(milliseconds: 350),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, __, ___) => SongPlayer(
        songModelList: songs,
        initialIndex: index,
        attach: attach,
        shuffle: shuffle,
      ),
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: FadeTransition(opacity: curved, child: child),
        );
      },
    ),
  );
}

class SongPlayer extends StatefulWidget {
  const SongPlayer({
    super.key,
    required this.songModelList,
    this.initialIndex = 0,
    this.attach = false,
    this.shuffle = false,
  });

  final List<SongModel> songModelList;
  final int initialIndex;

  /// When true, bind to what's already playing (opened from the mini-player)
  /// instead of loading the queue from scratch.
  final bool attach;

  /// Shuffle mode to apply when (re)loading the queue.
  final bool shuffle;

  @override
  State<SongPlayer> createState() => _SongPlayerState();
}

class _SongPlayerState extends State<SongPlayer> {
  AudioPlayer get _player => PlayerHost.instance.player;

  Duration _duration = const Duration();
  bool _isPlaying = false;

  int currentIndex = 0;
  // just_audio replays a transient/stale index while setAudioSource applies
  // initialIndex. Stays false until the stream settles on the opened song.
  bool _indexSettled = false;
  RangeValues _currentRangeValues = const RangeValues(0.0, 0.0);
  RangeLabels _currentRangeLabels = const RangeLabels("0", "0");

  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<int?>? _currentIndexSub;

  // Count-in (opt-in): the 3 beeps + UI state. Uses the audioplayers engine —
  // a second just_audio player would fight the main player for the single
  // just_audio_background (media session) instance and break all playback.
  final beeper.AudioPlayer _beepPlayer = beeper.AudioPlayer();
  bool _isCountingIn = false;
  int _countInValue = 0;

  /// Dominant colour of the current song's album art, used to tint the player
  /// background. Null when the song has no embedded artwork.
  Color? _artColor;

  /// Cache of computed dominant colours by song id (shared across player
  /// instances) so revisiting a song is instant — no repeated image decode.
  /// A present key with a null value means "checked, has no artwork".
  static final Map<int, Color?> _artColorCache = {};

  SongModel get _currentSong => widget.songModelList[currentIndex];

  Future<void> _loadArtColor() async {
    final int id = _currentSong.id;
    if (_artColorCache.containsKey(id)) {
      if (mounted) setState(() => _artColor = _artColorCache[id]);
      return;
    }
    try {
      final bytes =
          await OnAudioQuery().queryArtwork(id, ArtworkType.AUDIO, size: 200);
      if (bytes == null || bytes.isEmpty) {
        _artColorCache[id] = null;
        if (mounted) setState(() => _artColor = null);
        return;
      }
      final codec = await ui.instantiateImageCodec(bytes,
          targetWidth: 8, targetHeight: 8);
      final frame = await codec.getNextFrame();
      final data =
          await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (data == null) return;
      final px = data.buffer.asUint8List();
      Color best = const Color(0xFF000000);
      double bestScore = -1;
      for (int i = 0; i + 4 <= px.length; i += 4) {
        final color = Color.fromARGB(255, px[i], px[i + 1], px[i + 2]);
        final hsv = HSVColor.fromColor(color);
        final score = hsv.saturation * hsv.value;
        if (score > bestScore) {
          bestScore = score;
          best = color;
        }
      }
      _artColorCache[id] = best;
      if (mounted) setState(() => _artColor = best);
    } catch (_) {
      if (mounted) setState(() => _artColor = null);
    }
  }

  void popBack() {
    Navigator.pop(context);
  }

  void seekToSeconds(int seconds) {
    _player.seek(Duration(seconds: seconds));
  }

  /// Skip back/forward a few seconds — dancers rewinding "just that move".
  void _nudge(int seconds) {
    HapticFeedback.selectionClick();
    final target = _player.position + Duration(seconds: seconds);
    final max = _duration;
    _player.seek(target < Duration.zero
        ? Duration.zero
        : (target > max ? max : target));
  }

  void resetConfigurations() {
    final id = _currentSong.id;
    _player.setSpeed(1.0);
    PrefsService.instance.setSpeed(id, 1.0);
    PrefsService.instance.clearLoop(id);
    setState(() {
      _currentRangeValues = RangeValues(0, _duration.inSeconds.toDouble());
      _syncRangeLabels();
    });
    PlayerHost.instance
        .setSectionLoop(0, _duration.inSeconds.toDouble());
    playAudio();
  }

  Future<void> playAudio() async {
    final posSec = _player.position.inMilliseconds / 1000.0;
    if (posSec <= _currentRangeValues.start ||
        posSec >= _currentRangeValues.end) {
      _player.seek(Duration(seconds: _currentRangeValues.start.toInt()));
    }
    _player.play();
  }

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    // Our asset key is 'lib/assets/beep.wav'; audioplayers prefixes 'assets/'
    // by default, so clear the prefix.
    _beepPlayer.audioCache = beeper.AudioCache(prefix: '');
    _beepPlayer
        .setSource(beeper.AssetSource('lib/assets/beep.wav'))
        .catchError((_) {});
    // Deferred: setQueue notifies the mini-player's ValueListenableBuilder,
    // which sits in the still-building home tree below this route — notifying
    // synchronously from initState is a markNeedsBuild-during-build error.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _initPlayback();
    });
  }

  Future<void> _initPlayback() async {
    try {
      if (widget.attach) {
        // Bind to ongoing playback without restarting it.
        _indexSettled = true;
        final i = _player.currentIndex;
        if (i != null && i >= 0 && i < widget.songModelList.length) {
          currentIndex = i;
        }
        _isPlaying = _player.playing;
      } else {
        await PlayerHost.instance
            .setQueue(widget.songModelList, widget.initialIndex);
        await _player.setShuffleModeEnabled(widget.shuffle);
        playAudio();
      }
      _listenToDuration();
      _listenToPlayerState();
      _listenToSongIndex();
      _loadArtColor();
    } on Exception catch (e, st) {
      debugPrint('AudioMark: player init failed: $e\n$st');
      popBack();
    }
  }

  void _syncRangeLabels() {
    _currentRangeLabels = RangeLabels(
      _formatTime(Duration(seconds: _currentRangeValues.start.toInt())),
      _formatTime(Duration(seconds: _currentRangeValues.end.toInt())),
    );
  }

  void _listenToDuration() {
    _durationSub = PlayerHost.instance.durationStream.listen((duration) {
      if (duration == null || !mounted) return;
      setState(() {
        _duration = duration;
        final saved = PrefsService.instance.getLoop(_currentSong.id);
        final double max = _duration.inSeconds.toDouble();
        if (saved != null) {
          _currentRangeValues = RangeValues(
            saved[0].toDouble().clamp(0.0, max),
            saved[1].toDouble().clamp(0.0, max),
          );
        } else {
          _currentRangeValues = RangeValues(0, max);
        }
        _syncRangeLabels();
      });
      PlayerHost.instance.setSectionLoop(
          _currentRangeValues.start, _currentRangeValues.end);
    });
  }

  void _listenToPlayerState() {
    _playerStateSub = PlayerHost.instance.playerStateStream.listen((state) {
      if (!mounted) return;
      final playing =
          state.playing && state.processingState != ProcessingState.completed;
      if (playing != _isPlaying) {
        setState(() => _isPlaying = playing);
      }
      // Keep the screen on during practice (opt-out in Settings).
      if (playing && PrefsService.instance.keepAwakeEnabled) {
        WakelockPlus.enable();
      } else {
        WakelockPlus.disable();
      }
    });
  }

  void _listenToSongIndex() {
    _currentIndexSub = PlayerHost.instance.currentIndexStream.listen((event) {
      if (!mounted) return;
      // The queue in this screen mirrors PlayerHost's; ignore out-of-range or
      // stale emissions (see PlayerHost for the settling rationale).
      if (event == null ||
          event < 0 ||
          event >= widget.songModelList.length) {
        return;
      }
      if (!_indexSettled) {
        if (event == widget.initialIndex) {
          _indexSettled = true;
          _loadArtColor();
        }
        return;
      }
      if (event == currentIndex) return;
      setState(() {
        currentIndex = event;
        context.read<SongModelProvider>().setId(_currentSong.id);
      });
      _loadArtColor();
    });
  }

  /// Plays 3 beeps (~0.5s apart) and starts playback on the third — a count-in
  /// for dancers, gated behind the global toggle.
  Future<void> _countInThenPlay() async {
    setState(() => _isCountingIn = true);
    for (int n = 3; n >= 1; n--) {
      if (!mounted) return;
      setState(() => _countInValue = n);
      try {
        await _beepPlayer.stop();
        await _beepPlayer.resume(); // restarts the loaded beep from 0
      } catch (_) {}
      if (n > 1) await Future.delayed(const Duration(milliseconds: 500));
    }
    if (!mounted) return;
    setState(() {
      _isCountingIn = false;
      _countInValue = 0;
    });
    playAudio();
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _playerStateSub?.cancel();
    _currentIndexSub?.cancel();
    _beepPlayer.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  String _formatTime(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    return hours > 0
        ? '$hours:${two(minutes)}:${two(seconds)}'
        : '$minutes:${two(seconds)}';
  }

  // ---- Tap tempo -------------------------------------------------------------

  /// Tap-along sheet: BPM from the average wall-clock gap between taps
  /// (converted to song-time), first tap marks the downbeat ("1").
  void _openTapTempo() {
    final id = _currentSong.id;
    final taps = <int>[]; // wall-clock ms per tap
    int? anchorPos; // playback position (ms) at the first tap = the downbeat
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final scheme = Theme.of(ctx).colorScheme;
          double? bpm;
          if (taps.length >= 2) {
            final deltas = <int>[];
            for (int i = 1; i < taps.length; i++) {
              final d = taps[i] - taps[i - 1];
              if (d > 0) deltas.add(d);
            }
            if (deltas.isNotEmpty) {
              final avg = deltas.reduce((a, b) => a + b) / deltas.length;
              // Tap intervals are wall-clock; convert to song-time so the count
              // lines up even if tapped while slowed down.
              final speed = _player.speed <= 0 ? 1.0 : _player.speed;
              final songBpm = (60000 / avg) / speed;
              if (songBpm > 30 && songBpm < 300) bpm = songBpm;
            }
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Tap the tempo',
                    style: TextStyle(
                        color: scheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text('Play the song and tap each beat, starting on the “1”.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 14),
                Text(bpm != null ? '${bpm.round()} BPM' : '— BPM',
                    style: TextStyle(
                        color: scheme.primary,
                        fontSize: 30,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: () {
                    anchorPos ??= _player.position.inMilliseconds;
                    taps.add(DateTime.now().millisecondsSinceEpoch);
                    HapticFeedback.selectionClick();
                    setSheet(() {});
                  },
                  child: Container(
                    height: 92,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    alignment: Alignment.center,
                    child: Text('TAP',
                        style: TextStyle(
                            color: scheme.onPrimaryContainer,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2)),
                  ),
                ),
                const SizedBox(height: 6),
                Text('${taps.length} taps',
                    style: TextStyle(
                        color: scheme.onSurfaceVariant, fontSize: 12)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: () {
                        PrefsService.instance.clearTempo(id);
                        setState(() {});
                        Navigator.pop(ctx);
                      },
                      child: const Text('Clear'),
                    ),
                    Row(
                      children: [
                        TextButton(
                          onPressed: taps.isEmpty
                              ? null
                              : () {
                                  taps.clear();
                                  anchorPos = null;
                                  setSheet(() {});
                                },
                          child: const Text('Reset'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: bpm == null
                              ? null
                              : () {
                                  PrefsService.instance
                                      .setTempo(id, bpm!, anchorPos ?? 0);
                                  setState(() {});
                                  Navigator.pop(ctx);
                                },
                          child: const Text('Save'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ---- Sections ----------------------------------------------------------------

  void _openSections() {
    showLoopSectionsSheet(
      context,
      songId: _currentSong.id,
      currentStartSec: _currentRangeValues.start.toInt(),
      currentEndSec: _currentRangeValues.end.toInt(),
      onApply: (LoopSection s) {
        final double max = _duration.inSeconds.toDouble();
        setState(() {
          _currentRangeValues = RangeValues(
            s.startSec.toDouble().clamp(0.0, max),
            s.endSec.toDouble().clamp(0.0, max),
          );
          _syncRangeLabels();
        });
        PrefsService.instance
            .setLoop(_currentSong.id, s.startSec, s.endSec);
        PlayerHost.instance.setSectionLoop(
            _currentRangeValues.start, _currentRangeValues.end);
        _player.setLoopMode(LoopMode.all); // looping is the point of a section
        seekToSeconds(s.startSec);
        _player.play();
      },
    );
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Song details'),
              subtitle: Text(_currentSong.displayNameWOExt),
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_border_rounded),
              title: const Text('Practice sections'),
              onTap: () {
                Navigator.pop(sheetContext);
                _openSections();
              },
            ),
            ListTile(
              leading: const Icon(Icons.restart_alt_rounded),
              title: const Text('Reset speed & loop'),
              onTap: () {
                Navigator.pop(sheetContext);
                resetConfigurations();
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () {
                Navigator.pop(sheetContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SettingsScreen()),
                ).then((_) {
                  if (mounted) setState(() {});
                });
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ---- Build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final song = _currentSong;
    final artist = song.artist;
    final hasArtist = artist != null && artist != '<unknown>';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(
                (_artColor ?? songColorForId(song.id))
                    .withValues(alpha: 0.45),
                scheme.surface,
              ),
              scheme.surface,
            ],
            stops: const [0.0, 0.55],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: popBack,
                      tooltip: 'Back to library',
                      icon: const Icon(Icons.keyboard_arrow_down_rounded,
                          size: 28),
                    ),
                    Text('NOW PLAYING',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 2.4,
                          color: scheme.onSurfaceVariant,
                        )),
                    IconButton(
                      onPressed: _showMoreMenu,
                      tooltip: 'More',
                      icon: Icon(Icons.more_horiz_rounded,
                          color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                // Artwork — flexes to whatever height is left so the layout
                // never overflows on small screens.
                Expanded(
                  child: Center(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = [
                          constraints.maxWidth - 24,
                          constraints.maxHeight,
                          320.0
                        ].reduce((a, b) => a < b ? a : b);
                        return AnimatedScale(
                          scale: _isPlaying ? 1.0 : 0.94,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                          child: ArtWorkWidget(size: size),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Title + artist + favourite
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.displayNameWOExt,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 21.0,
                              letterSpacing: -0.3,
                            ),
                          ),
                          if (hasArtist)
                            Padding(
                              padding: const EdgeInsets.only(top: 2.0),
                              child: Text(
                                artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                  fontSize: 14.5,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    FavoriteButton(songId: song.id),
                  ],
                ),
                const SizedBox(height: 4),
                // Progress (isolated: re-renders on position ticks, not the
                // whole screen)
                _ProgressSection(
                  player: _player,
                  duration: _duration,
                  formatTime: _formatTime,
                ),
                const SizedBox(height: 8),
                // Practice card: loop section + 8-count — the dancer toolkit.
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: scheme.outlineVariant.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Icon(Icons.repeat_rounded,
                              size: 15, color: scheme.onSurfaceVariant),
                          const SizedBox(width: 6),
                          Text(
                            'LOOP SECTION',
                            style: TextStyle(
                              color: scheme.onSurfaceVariant,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '${_formatTime(Duration(seconds: _currentRangeValues.start.toInt()))} – ${_formatTime(Duration(seconds: _currentRangeValues.end.toInt()))}',
                            style: TextStyle(
                                color: scheme.onSurfaceVariant, fontSize: 12),
                          ),
                          IconButton(
                            tooltip: 'Saved sections',
                            visualDensity: VisualDensity.compact,
                            onPressed: _openSections,
                            icon: Icon(Icons.bookmark_border_rounded,
                                size: 20, color: scheme.onSurfaceVariant),
                          ),
                          LoopButton(audioPlayer: _player),
                        ],
                      ),
                      RangeSlider(
                        activeColor: scheme.primary,
                        inactiveColor: scheme.surfaceContainerHighest,
                        values: _currentRangeValues,
                        min: 0.0,
                        max: _duration.inSeconds.toDouble(),
                        labels: _currentRangeLabels,
                        onChanged: (RangeValues value) {
                          setState(() {
                            _currentRangeValues = value;
                            _syncRangeLabels();
                          });
                        },
                        onChangeEnd: (RangeValues value) {
                          PrefsService.instance.setLoop(
                            song.id,
                            value.start.toInt(),
                            value.end.toInt(),
                          );
                          PlayerHost.instance
                              .setSectionLoop(value.start, value.end);
                        },
                      ),
                      _BeatStrip(
                        player: _player,
                        songId: song.id,
                        onOpenTapTempo: _openTapTempo,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // Transport
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      tooltip: 'Back 5 seconds',
                      onPressed: () => _nudge(-5),
                      icon: Icon(Icons.replay_5_rounded,
                          size: 30, color: scheme.onSurfaceVariant),
                    ),
                    IconButton(
                      tooltip: 'Previous',
                      onPressed: () {
                        if (_player.hasPrevious) _player.seekToPrevious();
                      },
                      icon: CircleAvatar(
                        radius: 26,
                        backgroundColor: scheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.skip_previous_rounded,
                          color: scheme.onSurfaceVariant,
                          size: 24.0,
                        ),
                      ),
                    ),
                    IconButton(
                      iconSize: 72,
                      onPressed: () {
                        if (_isCountingIn) return;
                        HapticFeedback.lightImpact();
                        if (_isPlaying) {
                          _player.pause();
                          return;
                        }
                        if (_player.position >= _duration) seekToSeconds(0);
                        if (PrefsService.instance.countInEnabled) {
                          _countInThenPlay();
                        } else {
                          playAudio();
                        }
                      },
                      icon: CircleAvatar(
                        radius: 36,
                        backgroundColor: scheme.primary,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 220),
                          transitionBuilder: (child, anim) =>
                              ScaleTransition(scale: anim, child: child),
                          child: _isCountingIn
                              ? Text(
                                  '$_countInValue',
                                  key: ValueKey<int>(_countInValue),
                                  style: TextStyle(
                                    color: scheme.onPrimary,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : Icon(
                                  _isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  key: ValueKey<bool>(_isPlaying),
                                  color: scheme.onPrimary,
                                  size: 38.0,
                                ),
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Next',
                      onPressed: () {
                        if (_player.hasNext) _player.seekToNext();
                      },
                      icon: CircleAvatar(
                        radius: 26,
                        backgroundColor: scheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.skip_next_rounded,
                          color: scheme.onSurfaceVariant,
                          size: 24.0,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Forward 5 seconds',
                      onPressed: () => _nudge(5),
                      icon: Icon(Icons.forward_5_rounded,
                          size: 30, color: scheme.onSurfaceVariant),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Secondary controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ShuffleButton(audioPlayer: _player),
                    AdjustSpeed(audioPlayer: _player, songId: song.id),
                    IconButton(
                      tooltip: 'Count-in (3 beeps before play)',
                      onPressed: () {
                        PrefsService.instance.setCountInEnabled(
                            !PrefsService.instance.countInEnabled);
                        setState(() {});
                      },
                      icon: Icon(
                        Icons.av_timer_rounded,
                        color: PrefsService.instance.countInEnabled
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Progress slider + time labels in an isolated widget so the ~5 Hz position
/// ticks re-render only this subtree, not the whole player screen.
class _ProgressSection extends StatefulWidget {
  const _ProgressSection({
    required this.player,
    required this.duration,
    required this.formatTime,
  });

  final AudioPlayer player;
  final Duration duration;
  final String Function(Duration) formatTime;

  @override
  State<_ProgressSection> createState() => _ProgressSectionState();
}

class _ProgressSectionState extends State<_ProgressSection> {
  StreamSubscription<Duration>? _sub;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();
    _sub = PlayerHost.instance.positionStream.listen((position) {
      if (!mounted) return;
      setState(() => _position = position);
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final maxSec = widget.duration.inSeconds.toDouble();
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
          ),
          child: Slider(
            activeColor: scheme.primary,
            inactiveColor: scheme.surfaceContainerHighest,
            min: 0.0,
            max: maxSec,
            value: _position.inSeconds.toDouble().clamp(0.0, maxSec),
            onChanged: (value) =>
                widget.player.seek(Duration(seconds: value.toInt())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(widget.formatTime(_position),
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
              Text(widget.formatTime(widget.duration),
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    );
  }
}

/// The 1–8 count strip (when a tempo is set) or a "tap tempo" prompt. Runs its
/// own 100 ms ticker and only rebuilds itself when the beat changes.
class _BeatStrip extends StatefulWidget {
  const _BeatStrip({
    required this.player,
    required this.songId,
    required this.onOpenTapTempo,
  });

  final AudioPlayer player;
  final int songId;
  final VoidCallback onOpenTapTempo;

  @override
  State<_BeatStrip> createState() => _BeatStripState();
}

class _BeatStripState extends State<_BeatStrip> {
  Timer? _timer;
  int _currentBeat = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      if (!mounted) return;
      final b = _computeBeat();
      if (b != _currentBeat) setState(() => _currentBeat = b);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Current 8-count (1..8) from the live playback position + saved tempo, or
  /// 0 when no tempo is set for this song.
  int _computeBeat() {
    final bpm = PrefsService.instance.getBpm(widget.songId);
    if (bpm <= 0) return 0;
    final anchor = PrefsService.instance.getBeatAnchorMs(widget.songId);
    final beatMs = 60000.0 / bpm;
    final beats =
        ((widget.player.position.inMilliseconds - anchor) / beatMs).floor();
    return ((beats % 8) + 8) % 8 + 1;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bpm = PrefsService.instance.getBpm(widget.songId);
    if (bpm <= 0) {
      return Center(
        child: TextButton.icon(
          onPressed: widget.onOpenTapTempo,
          icon: const Icon(Icons.touch_app_outlined, size: 18),
          label: const Text('Tap tempo · 8-count'),
        ),
      );
    }
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(8, (i) {
            final n = i + 1;
            final active = n == _currentBeat;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                width: active ? 30 : 24,
                height: active ? 30 : 24,
                decoration: BoxDecoration(
                  color:
                      active ? scheme.primary : scheme.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text('$n',
                    style: TextStyle(
                        color: active
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                        fontWeight: FontWeight.bold,
                        fontSize: active ? 14 : 12)),
              ),
            );
          }),
        ),
        const SizedBox(height: 2),
        TextButton(
          onPressed: widget.onOpenTapTempo,
          style: TextButton.styleFrom(
            minimumSize: Size.zero,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text('${bpm.round()} BPM · tap to adjust',
              style:
                  TextStyle(color: scheme.onSurfaceVariant, fontSize: 11)),
        ),
      ],
    );
  }
}

class ArtWorkWidget extends StatelessWidget {
  const ArtWorkWidget({super.key, this.size = 300});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final int id = context.watch<SongModelProvider>().id;
    return Hero(
      tag: 'artwork_$id',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.all(Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: QueryArtworkWidget(
          id: id,
          type: ArtworkType.AUDIO,
          artworkHeight: size,
          artworkWidth: size,
          artworkBorder: const BorderRadius.all(Radius.circular(28)),
          artworkFit: BoxFit.cover,
          nullArtworkWidget: Container(
            height: size,
            width: size,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: songGradientForId(id),
              ),
              borderRadius: const BorderRadius.all(Radius.circular(28)),
            ),
            child: Icon(
              Icons.music_note_rounded,
              size: size * 0.4,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
