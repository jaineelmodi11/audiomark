import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:provider/provider.dart';
import 'package:songhut/screens/songplayer/components/adjust_speed_button.dart';
import 'package:songhut/screens/songplayer/components/favorite_button.dart';
import 'package:songhut/screens/songplayer/components/loop_button.dart';
import 'package:songhut/screens/songplayer/components/shuffle_button.dart';
import 'package:songhut/screens/settings/settings_screen.dart';
import '../../constants.dart';
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

      widget.audioPlayer.durationStream.listen((duration) {
        if (duration != null) {
          setState(() {
            _duration = duration;

            _currentRangeValues =
                RangeValues(0, _duration.inSeconds.toDouble());
            _currentRangeLabels =
                RangeLabels("0", _duration.inSeconds.toString());
          });
        }
      });
      widget.audioPlayer.positionStream.listen((position) {
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
    } on Exception catch (_) {
      popBack();
    }
  }

  void listenToEvent() {
    widget.audioPlayer.playerStateStream.listen((state) {
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
    widget.audioPlayer.currentIndexStream.listen(
      (event) {
        setState(
          () {
            if (event != null) {
              currentIndex = event;
            }
            context
                .read<SongModelProvider>()
                .setId(widget.songModelList[currentIndex].id);
          },
        );
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
        body: Container(
          height: height,
          width: double.infinity,
          padding: const EdgeInsets.all(15.0),
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
                    const Center(
                      child: ArtWorkWidget(),
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
                            radius: 30,
                            backgroundColor: scheme.primary,
                            child: Icon(
                              color: scheme.onPrimary,
                              _isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 30.0,
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
    return QueryArtworkWidget(
      id: context.watch<SongModelProvider>().id,
      type: ArtworkType.AUDIO,
      artworkHeight: 300,
      artworkWidth: 300,
      artworkBorder: const BorderRadius.all(Radius.circular(30)),
      artworkFit: BoxFit.cover,
      nullArtworkWidget: Container(
        height: 300,
        width: 300,
        decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: const BorderRadius.all(Radius.circular(30))),
        child: Icon(
          Icons.music_note_rounded,
          size: 200,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}
