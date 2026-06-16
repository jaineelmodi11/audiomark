import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:songhut/screens/songplayer/components/adjust_speed_button.dart';
import 'package:songhut/screens/songplayer/components/favorite_button.dart';
import 'package:songhut/screens/songplayer/components/loop_button.dart';
import 'package:songhut/screens/songplayer/components/shuffle_button.dart';
import 'package:songhut/screens/settings/settings_screen.dart';
import 'package:songhut/utils/song_color.dart';
import '../../provider/songModelProvider.dart';

class SongPlayer extends StatefulWidget {
  const SongPlayer({
    super.key,
    required this.songModelList,
    required this.audioPlayer,
  });
  final List<SongModel> songModelList;
  final AudioPlayer audioPlayer;

  @override
  State<SongPlayer> createState() => _SongPlayerState();
}

class _SongPlayerState extends State<SongPlayer> {
  Duration _duration = const Duration();
  Duration _position = const Duration();

  bool _isPlaying = false;
  List<AudioSource> songList = [];

  int currentIndex = 0;
  RangeValues _currentRangeValues = const RangeValues(0.0, 0.0);
  RangeLabels _currentRangeLabels = const RangeLabels("0", "0");

  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<int?>? _currentIndexSub;

  /// Dominant colour of the current song's album art, used to tint the player
  /// background. Null when the song has no embedded artwork.
  Color? _artColor;

  /// Loads the current song's artwork and derives a vivid dominant colour by
  /// downscaling to an 8x8 grid and picking the most saturated, bright pixel.
  Future<void> _loadArtColor() async {
    final int id = widget.songModelList[currentIndex].id;
    try {
      final bytes =
          await OnAudioQuery().queryArtwork(id, ArtworkType.AUDIO, size: 200);
      if (bytes == null || bytes.isEmpty) {
        if (mounted) setState(() => _artColor = null);
        return;
      }
      final codec =
          await ui.instantiateImageCodec(bytes, targetWidth: 8, targetHeight: 8);
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
      if (mounted) setState(() => _artColor = best);
    } catch (_) {
      if (mounted) setState(() => _artColor = null);
    }
  }

  void popBack() {
    Navigator.pop(context);
  }

  void seekToSeconds(int seconds) {
    Duration duration = Duration(seconds: seconds);
    widget.audioPlayer.seek(duration);
  }

  void resetConfigurations() {
    widget.audioPlayer.setSpeed(1.0);
    _position = const Duration(seconds: 0);
    _currentRangeValues = RangeValues(0, _duration.inSeconds.toDouble());

    playAudio();
  }

  Future<void> playAudio() async {
    if (_position.inSeconds.toInt() <= _currentRangeValues.start.toInt() ||
        _position.inSeconds.toInt() >= _currentRangeValues.end.toInt()) {
      widget.audioPlayer
          .seek(Duration(seconds: _currentRangeValues.start.toInt()));
    }

    widget.audioPlayer.play();
    _isPlaying = true;
  }

  @override
  void initState() {
    super.initState();
    parseSong();
  }

  @override
  void dispose() {
    _durationSub?.cancel();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    _currentIndexSub?.cancel();
    super.dispose();
  }

  void parseSong() async {
    try {
      for (var element in widget.songModelList) {
        songList.add(
          AudioSource.uri(
            Uri.parse(element.uri!),
          ),
        );
      }
      widget.audioPlayer.setAudioSource(
        ConcatenatingAudioSource(children: songList),
      );

      _durationSub = widget.audioPlayer.durationStream.listen((duration) {
        if (duration != null) {
          if (!mounted) return;
          setState(() {
            _duration = duration;

            _currentRangeValues =
                RangeValues(0, _duration.inSeconds.toDouble());
            _currentRangeLabels =
                RangeLabels("0", _duration.inSeconds.toString());
          });
        }
      });
      _positionSub = widget.audioPlayer.positionStream.listen((position) {
        if (!mounted) return;
        setState(() {
          _position = position;
        });

        if (_position.inSeconds.toInt() >= _currentRangeValues.end.toInt()) {
          if (widget.audioPlayer.loopMode == LoopMode.all) {
            seekToSeconds(_currentRangeValues.start.toInt());
            playAudio();
          } else {
            widget.audioPlayer.pause();
          }
        }
      });

      playAudio();
      listenToEvent();
      listenToSongIndex();
      _loadArtColor();
    } on Exception catch (_) {
      popBack();
    }
  }

  void listenToEvent() {
    _playerStateSub = widget.audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;
      if (state.playing) {
        setState(() {
          _isPlaying = true;
        });
      } else {
        setState(() {
          _isPlaying = false;
        });
      }
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _isPlaying = false;
        });
      }
    });
  }

  void listenToSongIndex() {
    _currentIndexSub = widget.audioPlayer.currentIndexStream.listen(
      (event) {
        if (!mounted) return;
        // The AudioPlayer is shared, so its currentIndexStream can replay a
        // stale index from a previous (longer) queue before this player's
        // audio source resets it. Ignore indices outside our list to avoid a
        // RangeError when the player was opened with a single song.
        if (event == null || event < 0 || event >= widget.songModelList.length) {
          return;
        }
        setState(
          () {
            currentIndex = event;
            context
                .read<SongModelProvider>()
                .setId(widget.songModelList[currentIndex].id);
          },
        );
        _loadArtColor();
      },
    );
  }

  String _formatTime(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hours = d.inHours;
    final minutes = d.inMinutes % 60;
    final seconds = d.inSeconds % 60;
    return hours > 0 ? '$hours:${two(minutes)}:${two(seconds)}' : '$minutes:${two(seconds)}';
  }

  void _showMoreMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Song details'),
              subtitle:
                  Text(widget.songModelList[currentIndex].displayNameWOExt),
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
                );
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    double height = MediaQuery.of(context).size.height;
    return SafeArea(
      child: Scaffold(
        body: AnimatedContainer(
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOut,
          height: height,
          width: double.infinity,
          padding: const EdgeInsets.all(15.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.alphaBlend(
                  (_artColor ??
                          songColorForId(
                              widget.songModelList[currentIndex].id))
                      .withOpacity(0.5),
                  scheme.surface,
                ),
                scheme.surface,
              ],
              stops: const [0.0, 0.55],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () {
                      popBack();
                    },
                    icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  ),
                  const Text("Now Playing"),
                  IconButton(
                    onPressed: () {
                      _showMoreMenu();
                    },
                    icon: Icon(
                      Icons.more_horiz,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Center(
                      child: AnimatedScale(
                        scale: _isPlaying ? 1.0 : 0.94,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                        child: const ArtWorkWidget(),
                      ),
                    ),
                    const SizedBox(
                      height: 15.0,
                    ),
                    Text(
                      widget.songModelList[currentIndex].displayNameWOExt,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18.0,
                          overflow: TextOverflow.ellipsis),
                      maxLines: 1,
                    ),
                    Container(
                        margin: const EdgeInsets.only(top: 5.0),
                        child: widget.songModelList[currentIndex].artist !=
                                "<unknown>"
                            ? Text(
                                widget.songModelList[currentIndex].artist
                                    .toString(),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.normal,
                                    fontSize: 14.0,
                                    overflow: TextOverflow.ellipsis),
                                maxLines: 1,
                              )
                            : null),
                    const SizedBox(height: 12.0),
                    Row(
                      children: [
                        Icon(Icons.repeat_rounded,
                            size: 16, color: scheme.onSurfaceVariant),
                        const SizedBox(width: 6),
                        Text(
                          "Loop section",
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 12),
                        ),
                        const Spacer(),
                        Text(
                          "${_formatTime(Duration(seconds: _currentRangeValues.start.toInt()))}  -  ${_formatTime(Duration(seconds: _currentRangeValues.end.toInt()))}",
                          style: TextStyle(
                              color: scheme.onSurfaceVariant, fontSize: 12),
                        ),
                      ],
                    ),
                    RangeSlider(
                      activeColor: scheme.primary,
                      inactiveColor: scheme.surfaceVariant,
                      values: _currentRangeValues,
                      min: 0.0,
                      max: _duration.inSeconds.toDouble(),
                      labels: _currentRangeLabels,
                      onChanged: (RangeValues value) {
                        setState(() {
                          _currentRangeValues = value;
                          _currentRangeLabels = RangeLabels(
                              _formatTime(
                                  Duration(seconds: value.start.toInt())),
                              _formatTime(
                                  Duration(seconds: value.end.toInt())));
                        });
                      },
                    ),
                    Slider(
                      mouseCursor: SystemMouseCursors.grab,
                      activeColor: scheme.primary,
                      inactiveColor: scheme.surfaceVariant,
                      min: 0.0,
                      value: _position.inSeconds
                          .toDouble()
                          .clamp(0.0, _duration.inSeconds.toDouble()),
                      max: _duration.inSeconds.toDouble(),
                      onChanged: (value) {
                        setState(
                          () {
                            seekToSeconds(value.toInt());
                          },
                        );
                      },
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(_formatTime(_position)),
                        Text(_formatTime(_duration)),
                      ],
                    ),
                    const SizedBox(
                      height: 20.0,
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          onPressed: () {
                            if (widget.audioPlayer.hasPrevious) {
                              widget.audioPlayer.seekToPrevious();
                              resetConfigurations();
                            }
                          },
                          icon: CircleAvatar(
                            radius: 30,
                            backgroundColor: scheme.surfaceVariant,
                            child: Icon(
                              color: scheme.onSurfaceVariant,
                              Icons.skip_previous_rounded,
                              size: 20.0,
                            ),
                          ),
                        ),
                        IconButton(
                          iconSize: 60,
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            setState(() {
                              if (_isPlaying) {
                                widget.audioPlayer.pause();
                              } else {
                                if (_position >= _duration) {
                                  seekToSeconds(0);
                                } else {
                                  playAudio();
                                }
                              }
                              _isPlaying = !_isPlaying;
                            });
                          },
                          icon: CircleAvatar(
                            radius: 32,
                            backgroundColor: scheme.primary,
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 220),
                              transitionBuilder: (child, anim) =>
                                  ScaleTransition(scale: anim, child: child),
                              child: Icon(
                                _isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                key: ValueKey<bool>(_isPlaying),
                                color: scheme.onPrimary,
                                size: 32.0,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            if (widget.audioPlayer.hasNext) {
                              widget.audioPlayer.seekToNext();
                              resetConfigurations();
                            }
                          },
                          icon: CircleAvatar(
                            radius: 30,
                            backgroundColor: scheme.surfaceVariant,
                            child: Icon(
                              color: scheme.onSurfaceVariant,
                              Icons.skip_next_rounded,
                              size: 20.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8.0),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        FavoriteButton(audioPlayer: widget.audioPlayer),
                        ShuffleButton(audioPlayer: widget.audioPlayer),
                        AdjustSpeed(audioPlayer: widget.audioPlayer),
                        LoopButton(audioPlayer: widget.audioPlayer),
                      ],
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ArtWorkWidget extends StatelessWidget {
  const ArtWorkWidget({
    Key? key,
  }) : super(key: key);

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
              color: scheme.shadow.withOpacity(0.18),
              blurRadius: 28,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: QueryArtworkWidget(
          id: id,
          type: ArtworkType.AUDIO,
          artworkHeight: 300,
          artworkWidth: 300,
          artworkBorder: const BorderRadius.all(Radius.circular(28)),
          artworkFit: BoxFit.cover,
          nullArtworkWidget: Container(
            height: 300,
            width: 300,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: songGradientForId(id),
              ),
              borderRadius: const BorderRadius.all(Radius.circular(28)),
            ),
            child: const Icon(
              Icons.music_note_rounded,
              size: 120,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
