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
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) =>
            SongPlayer(songModelList: songs, audioPlayer: _audioPlayer),
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
            return const _LoadingSkeleton();
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
              return _FadeSlideIn(
                index: index,
                child: MusicTile(
                  songModel: song,
                  onTap: () => _openPlayer(context, [song], song.id),
                ),
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

/// Fades and slides a child up into place, staggered by its list index, so the
/// song list cascades in as it appears. Runs once on first mount.
class _FadeSlideIn extends StatefulWidget {
  final int index;
  final Widget child;

  const _FadeSlideIn({required this.index, required this.child});

  @override
  State<_FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<_FadeSlideIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );
  late final Animation<double> _curve =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(
      Duration(milliseconds: 60 * widget.index),
      () {
        if (mounted) _controller.forward();
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// A gently pulsing placeholder list shown while the music library loads,
/// instead of a bare spinner.
class _LoadingSkeleton extends StatefulWidget {
  const _LoadingSkeleton();

  @override
  State<_LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<_LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Color base = Theme.of(context).colorScheme.surfaceVariant;
    Widget bar(double width, double height) => Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: base,
            borderRadius: BorderRadius.circular(6),
          ),
        );
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: 8,
      itemBuilder: (context, index) => FadeTransition(
        opacity: Tween<double>(begin: 0.35, end: 0.8).animate(_controller),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: base,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    bar(double.infinity, 14),
                    const SizedBox(height: 8),
                    bar(140, 12),
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
