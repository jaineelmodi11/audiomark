import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:songhut/screens/songplayer/song_player.dart';
import 'package:songhut/services/player_host.dart';
import 'package:songhut/utils/song_color.dart';

/// Floating now-playing bar docked at the bottom of the home screen. Appears
/// once something has played; tap to reopen the full player without
/// interrupting playback.
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    final host = PlayerHost.instance;
    return ValueListenableBuilder<List<SongModel>>(
      valueListenable: host.queueListenable,
      builder: (context, queue, _) {
        if (queue.isEmpty) return const SizedBox.shrink();
        return StreamBuilder<int?>(
          // Stable stream instance from the host — never player.xStream
          // getters here (see PlayerHost docs).
          stream: host.currentIndexStream,
          builder: (context, snapshot) {
            final song = host.currentSong;
            if (song == null) return const SizedBox.shrink();
            return _MiniPlayerBar(song: song, player: host.player);
          },
        );
      },
    );
  }
}

class _MiniPlayerBar extends StatelessWidget {
  const _MiniPlayerBar({required this.song, required this.player});

  final SongModel song;
  final AudioPlayer player;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final artist = song.artist;
    final hasArtist = artist != null && artist != '<unknown>';

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: Material(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          elevation: 3,
          shadowColor: scheme.shadow.withValues(alpha: 0.35),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              final index = player.currentIndex ?? 0;
              openSongPlayer(
                context,
                songs: PlayerHost.instance.queue,
                index: index,
                attach: true, // rebind UI; don't restart playback
              );
            },
            child: SizedBox(
              height: 60,
              child: Stack(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: QueryArtworkWidget(
                            id: song.id,
                            type: ArtworkType.AUDIO,
                            artworkHeight: 42,
                            artworkWidth: 42,
                            artworkBorder: BorderRadius.circular(11),
                            artworkFit: BoxFit.cover,
                            nullArtworkWidget: Container(
                              height: 42,
                              width: 42,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: songGradientForId(song.id),
                                ),
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(Icons.music_note_rounded,
                                  color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                song.displayNameWOExt,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13.5),
                              ),
                              if (hasArtist)
                                Text(
                                  artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: scheme.onSurfaceVariant,
                                      fontSize: 11.5),
                                ),
                            ],
                          ),
                        ),
                        StreamBuilder<PlayerState>(
                          stream: PlayerHost.instance.playerStateStream,
                          builder: (context, snapshot) {
                            final playing = snapshot.data?.playing ?? false;
                            return IconButton.filledTonal(
                              tooltip: playing ? 'Pause' : 'Play',
                              onPressed: () {
                                HapticFeedback.lightImpact();
                                playing ? player.pause() : player.play();
                              },
                              icon: Icon(
                                playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                size: 22,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // Thin progress line along the bottom edge.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: StreamBuilder<Duration>(
                      stream: PlayerHost.instance.positionStream,
                      builder: (context, snapshot) {
                        final pos = snapshot.data ?? Duration.zero;
                        final dur = player.duration ?? Duration.zero;
                        final t = dur.inMilliseconds == 0
                            ? 0.0
                            : (pos.inMilliseconds / dur.inMilliseconds)
                                .clamp(0.0, 1.0);
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: t,
                            child: Container(
                              height: 2.5,
                              color: scheme.primary,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
