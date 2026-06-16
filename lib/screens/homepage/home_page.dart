import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart';
import 'package:songhut/screens/songplayer/song_player.dart';
import '../../provider/songModelProvider.dart';
import 'components/music_tile.dart';

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _HomePage();
}

class _HomePage extends State<MyHomePage> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _audioPlayer = AudioPlayer();

  requestPermission() async {
    if (!kIsWeb) {
      bool permissionStatus = await _audioQuery.permissionsStatus();
      if (!permissionStatus) {
        await _audioQuery.permissionsRequest();
      }
      setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
    requestPermission();
  }

  void _openPlayer(BuildContext context, List<SongModel> songs, int startId) {
    context.read<SongModelProvider>().setId(startId);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            SongPlayer(songModelList: songs, audioPlayer: _audioPlayer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AudioMark')),
      body: FutureBuilder<List<SongModel>>(
        future: _audioQuery.querySongs(
          sortType: null,
          orderType: OrderType.ASC_OR_SMALLER,
          uriType: UriType.EXTERNAL,
          ignoreCase: true,
        ),
        builder: (context, item) {
          if (item.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (item.hasError) {
            return _emptyState(
              context,
              Icons.error_outline,
              'Something went wrong while loading your music.',
            );
          }

          final List<SongModel> songs = item.data ?? <SongModel>[];
          if (songs.isEmpty) {
            return _emptyState(
              context,
              Icons.library_music_outlined,
              "No songs found on this device.\nMake sure you've granted music access.",
            );
          }

          return ListView.separated(
            itemCount: songs.length,
            padding: const EdgeInsets.only(bottom: 96),
            separatorBuilder: (_, __) =>
                const Divider(height: 1, indent: 80, endIndent: 16),
            itemBuilder: (context, index) {
              final song = songs[index];
              return MusicTile(
                songModel: song,
                onTap: () => _openPlayer(context, [song], song.id),
              );
            },
          );
        },
      ),
      floatingActionButton: FutureBuilder<List<SongModel>>(
        future: _audioQuery.querySongs(uriType: UriType.EXTERNAL),
        builder: (context, snapshot) {
          final songs = snapshot.data ?? <SongModel>[];
          if (songs.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _openPlayer(context, songs, songs.first.id),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Play all'),
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context, IconData icon, String message) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 64, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
