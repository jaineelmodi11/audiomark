import 'dart:async';
import 'dart:io' show Platform;
import 'dart:math' show Random;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:songhut/screens/homepage/components/mini_player.dart';
import 'package:songhut/screens/settings/settings_screen.dart';
import 'package:songhut/screens/songplayer/song_player.dart';
import 'package:songhut/services/imported_library.dart';
import 'package:songhut/services/prefs_service.dart';
import 'package:songhut/utils/song_color.dart';
import 'components/music_tile.dart';

enum _SortMode { nameAsc, recentlyAdded, duration }

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _HomePage();
}

class _HomePage extends State<MyHomePage> {
  // Lazy + only accessed on Android — instantiating on_audio_query on iOS
  // triggers an (unwanted) Apple Music / media-library permission prompt, and
  // iOS uses the app-managed ImportedLibrary instead.
  late final OnAudioQuery _audioQuery = OnAudioQuery();

  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _query = '';
  _SortMode _sort = _SortMode.nameAsc;
  bool _favoritesOnly = false;
  bool _hasPermission = false;
  // Cached so typing in search / changing sort doesn't re-run the query (which
  // would flash the loading skeleton on every keystroke).
  late Future<List<SongModel>> _songsFuture;

  Future<List<SongModel>> _querySongs() {
    // iOS has no shared MediaStore; serve the app-managed imported library.
    if (Platform.isIOS) return ImportedLibrary.instance.songs();
    return _audioQuery.querySongs(
      sortType: null,
      orderType: OrderType.ASC_OR_SMALLER,
      uriType: UriType.EXTERNAL,
      ignoreCase: true,
    );
  }

  void _refreshSongs() {
    if (!_hasPermission) return; // never query on_audio_query without access
    setState(() {
      _songsFuture = _querySongs();
    });
  }

  static const _importChannel = MethodChannel('audiomark/import');

  Future<void> _importAudio() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['mp3', 'm4a', 'mp4', 'aac', 'wav'],
    );
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    if (picked.path == null) return;
    try {
      if (Platform.isIOS) {
        // iOS: copy into the app's own library (no MediaStore).
        await ImportedLibrary.instance.importFile(picked.path!, picked.name);
        _refreshSongs();
      } else {
        await _importChannel.invokeMethod('importToMusic', {
          'path': picked.path,
          'name': picked.name,
        });
        // Let MediaStore finish indexing, then reload the library.
        await Future.delayed(const Duration(milliseconds: 600));
        _refreshSongs();
      }
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
    // Web and iOS aren't gated on a system permission: web has no native
    // library, and iOS serves an app-managed imported library from the app's
    // own sandbox (no Apple Music / media-library access needed).
    if (kIsWeb || Platform.isIOS) {
      setState(() => _hasPermission = true);
      _refreshSongs();
      return;
    }
    // Android: handle the permission ourselves with permission_handler —
    // on_audio_query 2.9.0's own request path crashes on Android 13.
    // READ_MEDIA_AUDIO on API 33+, READ_EXTERNAL_STORAGE below.
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

  void _openPlayer(List<SongModel> songs, int startIndex,
      {bool shuffle = false}) {
    openSongPlayer(context,
            songs: songs, index: startIndex, shuffle: shuffle)
        .then((_) {
      // Refresh on return so "Recently played" reflects the track just played.
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      bottomNavigationBar: const MiniPlayer(),
      body: FutureBuilder<List<SongModel>>(
        future: _songsFuture,
        builder: (context, item) {
          final List<SongModel> all = item.data ?? <SongModel>[];
          final bool loading =
              item.connectionState == ConnectionState.waiting;
          final List<SongModel> songs = _applyFilters(all);
          final List<SongModel> recents = (_query.isEmpty && !_favoritesOnly)
              ? _recentSongs(all)
              : const [];

          return CustomScrollView(
            slivers: [
              SliverAppBar.large(
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
                                value: _SortMode.nameAsc,
                                child: Text('Name (A–Z)')),
                            PopupMenuItem(
                                value: _SortMode.recentlyAdded,
                                child: Text('Recently added')),
                            PopupMenuItem(
                                value: _SortMode.duration,
                                child: Text('Duration')),
                          ],
                        ),
                        IconButton(
                          tooltip: 'Settings',
                          icon: const Icon(Icons.settings_outlined),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const SettingsScreen()),
                          ),
                        ),
                        const SizedBox(width: 4),
                      ],
              ),
              if (!_hasPermission)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _permissionState(context),
                )
              else if (loading)
                const SliverFillRemaining(child: _LoadingSkeleton())
              else if (item.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _emptyState(context, Icons.error_outline,
                      'Something went wrong while loading your music.'),
                )
              else if (all.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _emptyState(
                    context,
                    Icons.library_music_outlined,
                    Platform.isIOS
                        ? "No songs yet.\nTap + to import your audio."
                        : "No songs found on this device.\nMake sure you've granted music access.",
                    actionLabel: 'Import audio',
                    onAction: _importAudio,
                  ),
                )
              else ...[
                SliverToBoxAdapter(child: _searchField(scheme)),
                if (recents.isNotEmpty)
                  SliverToBoxAdapter(child: _recentsStrip(recents, all)),
                SliverToBoxAdapter(child: _libraryHeader(scheme, songs, all)),
                if (songs.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _emptyState(
                      context,
                      _favoritesOnly
                          ? Icons.favorite_border_rounded
                          : Icons.search_off_rounded,
                      _favoritesOnly
                          ? 'No favourites yet.\nTap the ♥ on a song to keep it here.'
                          : 'No songs match "$_query".',
                    ),
                  )
                else
                  SliverList.builder(
                    itemCount: songs.length,
                    itemBuilder: (context, i) {
                      final song = songs[i];
                      return Column(
                        children: [
                          _FadeSlideIn(
                            index: i,
                            child: MusicTile(
                              songModel: song,
                              onTap: () => _openPlayer(songs, i),
                              onFavoriteChanged: () {
                                if (_favoritesOnly) setState(() {});
                              },
                            ),
                          ),
                          if (i != songs.length - 1)
                            Divider(
                              height: 1,
                              indent: 86,
                              endIndent: 16,
                              color: scheme.outlineVariant
                                  .withValues(alpha: 0.4),
                            ),
                        ],
                      );
                    },
                  ),
                const SliverToBoxAdapter(child: SizedBox(height: 28)),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _searchField(ColorScheme scheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
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
          fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  /// "Library" header: filter chips, song count, and the Play all / Shuffle
  /// pills that act on the filtered list.
  Widget _libraryHeader(
      ColorScheme scheme, List<SongModel> songs, List<SongModel> all) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ChoiceChip(
                label: const Text('All'),
                selected: !_favoritesOnly,
                showCheckmark: false,
                onSelected: (_) => setState(() => _favoritesOnly = false),
              ),
              const SizedBox(width: 8),
              ChoiceChip(
                avatar: Icon(
                  Icons.favorite_rounded,
                  size: 16,
                  color: _favoritesOnly
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                ),
                label: const Text('Favourites'),
                selected: _favoritesOnly,
                showCheckmark: false,
                onSelected: (_) => setState(() => _favoritesOnly = true),
              ),
              const Spacer(),
              Text(
                '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
                style:
                    TextStyle(color: scheme.onSurfaceVariant, fontSize: 12.5),
              ),
            ],
          ),
          if (songs.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _openPlayer(songs, 0),
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Play all'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: () => _openPlayer(
                      songs,
                      Random().nextInt(songs.length),
                      shuffle: true,
                    ),
                    icon: const Icon(Icons.shuffle_rounded),
                    label: const Text('Shuffle'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  List<SongModel> _applyFilters(List<SongModel> all) {
    final q = _query.trim().toLowerCase();
    final favs = _favoritesOnly ? PrefsService.instance.favorites : null;
    final list = all.where((s) {
      if (favs != null && !favs.contains(s.id)) return false;
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
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Text('Recently played',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 17,
                  letterSpacing: -0.2)),
        ),
        SizedBox(
          height: 148,
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
                  _openPlayer(all, i < 0 ? 0 : i);
                },
                child: SizedBox(
                  width: 104,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: scheme.shadow.withValues(alpha: 0.10),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(18),
                          child: QueryArtworkWidget(
                            id: song.id,
                            type: ArtworkType.AUDIO,
                            artworkHeight: 104,
                            artworkWidth: 104,
                            artworkBorder: BorderRadius.circular(18),
                            artworkFit: BoxFit.cover,
                            nullArtworkWidget: Container(
                              height: 104,
                              width: 104,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: songGradientForId(song.id),
                                ),
                                borderRadius: BorderRadius.circular(18),
                              ),
                              child: const Icon(Icons.music_note_rounded,
                                  color: Colors.white, size: 34),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        song.displayNameWOExt,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
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
            _iconBadge(scheme, Icons.library_music_outlined),
            const SizedBox(height: 20),
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

  Widget _emptyState(BuildContext context, IconData icon, String message,
      {String? actionLabel, VoidCallback? onAction}) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _iconBadge(scheme, icon),
            const SizedBox(height: 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyLarge
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton.tonalIcon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _iconBadge(ColorScheme scheme, IconData icon) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primaryContainer,
            scheme.primaryContainer.withValues(alpha: 0.55),
          ],
        ),
      ),
      child: Icon(icon, size: 40, color: scheme.onPrimaryContainer),
    );
  }
}

/// Fades and slides a child up into place, staggered by its list index, so the
/// song list cascades in as it appears. Runs once on first mount; the stagger
/// is capped so deep list items don't wait noticeably.
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
    final cappedIndex = widget.index > 10 ? 10 : widget.index;
    Future.delayed(
      Duration(milliseconds: 50 * cappedIndex),
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
