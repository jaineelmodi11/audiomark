import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:songhut/screens/songplayer/song_player.dart';
import 'package:songhut/services/prefs_service.dart';
import 'package:songhut/utils/song_color.dart';
import '../../provider/song_model_provider.dart';
import 'components/music_tile.dart';

enum _SortMode { nameAsc, recentlyAdded, duration }

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _HomePage();
}

class _HomePage extends State<MyHomePage> {
  final OnAudioQuery _audioQuery = OnAudioQuery();
  final AudioPlayer _audioPlayer = AudioPlayer();

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';
  _SortMode _sort = _SortMode.nameAsc;
  bool _hasPermission = false;
  // Cached so typing in search / changing sort doesn't re-run the query (which
  // would flash the loading skeleton on every keystroke).
  late Future<List<SongModel>> _songsFuture;

  Future<List<SongModel>> _querySongs() => _audioQuery.querySongs(
        sortType: null,
        orderType: OrderType.ASC_OR_SMALLER,
        uriType: UriType.EXTERNAL,
        ignoreCase: true,
      );

  void _refreshSongs() {
    if (!_hasPermission) return; // never query on_audio_query without access
    setState(() {
      _songsFuture = _querySongs();
    });
  }

  static const _importChannel = MethodChannel('audiomark/import');

  Future<void> _importAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'mp4', 'aac', 'wav'],
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    if (picked.path == null) return;
    try {
      await _importChannel.invokeMethod('importToMusic', {
        'path': picked.path,
        'name': picked.name,
      });
      // Let MediaStore finish indexing, then reload the library.
      await Future.delayed(const Duration(milliseconds: 600));
      _refreshSongs();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Imported "${picked.name}"')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't import that file")),
        );
      }
    }
  }

  Future<void> requestPermission() async {
    if (kIsWeb) {
      setState(() => _hasPermission = true);
      return;
    }
    // Handle the permission ourselves with permission_handler — on_audio_query
    // 2.9.0's own request path crashes on Android 13. Use READ_MEDIA_AUDIO on
    // API 33+, READ_EXTERNAL_STORAGE below.
    int sdkInt = 33;
    try {
      sdkInt = await _importChannel.invokeMethod<int>('getSdkInt') ?? 33;
    } catch (_) {}
    final Permission perm =
        sdkInt >= 33 ? Permission.audio : Permission.storage;
    var status = await perm.status;
    if (!status.isGranted) {
      status = await perm.request();
    }
    if (!mounted) return;
    setState(() => _hasPermission = status.isGranted);
    if (status.isGranted) _refreshSongs();
  }

  @override
  void initState() {
    super.initState();
    // Don't query before permission is granted: on_audio_query crashes
    // (double channel reply) if querySongs runs without library access.
    // requestPermission() kicks off the first real query once granted.
    _songsFuture = Future.value(<SongModel>[]);
    requestPermission();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _openPlayer(BuildContext context, List<SongModel> songs, int startIndex) {
    // Always open within the full library so previous/next/shuffle are
    // meaningful, starting from the tapped song.
    context.read<SongModelProvider>().setId(songs[startIndex].id);
    Navigator.push(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        pageBuilder: (_, __, ___) => SongPlayer(
          songModelList: songs,
          audioPlayer: _audioPlayer,
          initialIndex: startIndex,
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('AudioMark'),
        actions: !_hasPermission
            ? const <Widget>[]
            : [
          IconButton(
            tooltip: 'Add music',
            icon: const Icon(Icons.add_rounded),
            onPressed: _importAudio,
          ),
          PopupMenuButton<_SortMode>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort_rounded),
            initialValue: _sort,
            onSelected: (m) => setState(() => _sort = m),
            itemBuilder: (context) => const [
              PopupMenuItem(
                  value: _SortMode.nameAsc, child: Text('Name (A–Z)')),
              PopupMenuItem(
                  value: _SortMode.recentlyAdded,
                  child: Text('Recently added')),
              PopupMenuItem(
                  value: _SortMode.duration, child: Text('Duration')),
            ],
          ),
        ],
      ),
      body: !_hasPermission
          ? _permissionState(context)
          : FutureBuilder<List<SongModel>>(
        future: _songsFuture,
        builder: (context, item) {
          if (item.connectionState == ConnectionState.waiting) {
            return const _LoadingSkeleton();
          }
          if (item.hasError) {
            return _emptyState(context, Icons.error_outline,
                'Something went wrong while loading your music.');
          }
          final List<SongModel> all = item.data ?? <SongModel>[];
          if (all.isEmpty) {
            return _emptyState(context, Icons.library_music_outlined,
                "No songs found on this device.\nMake sure you've granted music access.");
          }
          final List<SongModel> songs = _applySearchAndSort(all);
          final List<SongModel> recents =
              _query.isEmpty ? _recentSongs(all) : const [];
          return Column(
            children: [
              _searchField(scheme),
              Expanded(
                child: songs.isEmpty
                    ? _emptyState(context, Icons.search_off_rounded,
                        'No songs match "$_query".')
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 96),
                        itemCount:
                            songs.length + (recents.isNotEmpty ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (recents.isNotEmpty && index == 0) {
                            return _recentsStrip(recents, all);
                          }
                          final i = recents.isNotEmpty ? index - 1 : index;
                          final song = songs[i];
                          return Column(
                            children: [
                              _FadeSlideIn(
                                index: i,
                                child: MusicTile(
                                  songModel: song,
                                  onTap: () =>
                                      _openPlayer(context, songs, i),
                                ),
                              ),
                              if (i != songs.length - 1)
                                const Divider(
                                    height: 1, indent: 80, endIndent: 16),
                            ],
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FutureBuilder<List<SongModel>>(
        future: _songsFuture,
        builder: (context, snapshot) {
          final songs = _applySearchAndSort(snapshot.data ?? <SongModel>[]);
          if (songs.isEmpty) return const SizedBox.shrink();
          return FloatingActionButton.extended(
            onPressed: () => _openPlayer(context, songs, 0),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Play all'),
          );
        },
      ),
    );
  }

  Widget _searchField(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: TextField(
        controller: _searchController,
        onChanged: (v) {
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 250), () {
            if (mounted) setState(() => _query = v);
          });
        },
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search songs or artists',
          prefixIcon: const Icon(Icons.search_rounded),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close_rounded),
                  tooltip: 'Clear',
                  onPressed: () {
                    _searchDebounce?.cancel();
                    _searchController.clear();
                    setState(() => _query = '');
                    FocusScope.of(context).unfocus();
                  },
                ),
          filled: true,
          fillColor: scheme.surfaceContainerHighest.withOpacity(0.4),
          isDense: true,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  List<SongModel> _applySearchAndSort(List<SongModel> all) {
    final q = _query.trim().toLowerCase();
    final list = all.where((s) {
      if (q.isEmpty) return true;
      final title = s.displayNameWOExt.toLowerCase();
      final artist = (s.artist ?? '').toLowerCase();
      return title.contains(q) || artist.contains(q);
    }).toList();
    switch (_sort) {
      case _SortMode.nameAsc:
        list.sort((a, b) => a.displayNameWOExt
            .toLowerCase()
            .compareTo(b.displayNameWOExt.toLowerCase()));
        break;
      case _SortMode.recentlyAdded:
        list.sort((a, b) => (b.dateAdded ?? 0).compareTo(a.dateAdded ?? 0));
        break;
      case _SortMode.duration:
        list.sort((a, b) => (a.duration ?? 0).compareTo(b.duration ?? 0));
        break;
    }
    return list;
  }

  List<SongModel> _recentSongs(List<SongModel> all) {
    final byId = {for (final s in all) s.id: s};
    return PrefsService.instance.recentIds
        .map((id) => byId[id])
        .whereType<SongModel>()
        .take(10)
        .toList();
  }

  Widget _recentsStrip(List<SongModel> recents, List<SongModel> all) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Text('Recently played',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
        ),
        SizedBox(
          height: 140,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: recents.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final song = recents[index];
              return GestureDetector(
                onTap: () {
                  final i = all.indexWhere((s) => s.id == song.id);
                  _openPlayer(context, all, i < 0 ? 0 : i);
                },
                child: SizedBox(
                  width: 96,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: QueryArtworkWidget(
                          id: song.id,
                          type: ArtworkType.AUDIO,
                          artworkHeight: 96,
                          artworkWidth: 96,
                          artworkBorder: BorderRadius.circular(14),
                          artworkFit: BoxFit.cover,
                          nullArtworkWidget: Container(
                            height: 96,
                            width: 96,
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: songGradientForId(song.id),
                              ),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.music_note_rounded,
                                color: Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        song.displayNameWOExt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const Divider(height: 16),
      ],
    );
  }

  Widget _permissionState(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_music_outlined, size: 64, color: scheme.outline),
            const SizedBox(height: 16),
            Text(
              'AudioMark needs access to your audio to show your library.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: requestPermission,
              icon: const Icon(Icons.lock_open_rounded),
              label: const Text('Grant access'),
            ),
          ],
        ),
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
    final Color base = Theme.of(context).colorScheme.surfaceContainerHighest;
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
