import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:songhut/services/prefs_service.dart';
import 'package:songhut/utils/extensions/song_model_extension.dart';
import 'package:songhut/utils/song_color.dart';

class MusicTile extends StatefulWidget {
  final SongModel songModel;
  final VoidCallback? onTap;

  /// Fired after the heart toggles, so parents (e.g. a favourites-filtered
  /// list) can refresh.
  final VoidCallback? onFavoriteChanged;

  const MusicTile({
    super.key,
    required this.songModel,
    this.onTap,
    this.onFavoriteChanged,
  });

  @override
  State<MusicTile> createState() => _MusicTileState();
}

class _MusicTileState extends State<MusicTile> {
  SongModel get song => widget.songModel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool fav = PrefsService.instance.isFavorite(song.id);
    return ListTile(
      onTap: widget.onTap,
      onLongPress: () => _showDetails(context),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
      leading: Hero(
        tag: 'artwork_${song.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(13),
          child: QueryArtworkWidget(
            id: song.id,
            type: ArtworkType.AUDIO,
            artworkHeight: 54,
            artworkWidth: 54,
            artworkBorder: BorderRadius.circular(13),
            artworkFit: BoxFit.cover,
            nullArtworkWidget: Container(
              height: 54,
              width: 54,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: songGradientForId(song.id),
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.music_note_rounded,
                  color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
      title: Text(
        song.displayNameWOExt,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15.5),
      ),
      subtitle: Text(
        song.additionalSongInfo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
      ),
      trailing: IconButton(
        tooltip: fav ? 'Remove from favourites' : 'Add to favourites',
        onPressed: () async {
          HapticFeedback.lightImpact();
          await PrefsService.instance.toggleFavorite(song.id);
          if (mounted) setState(() {});
          widget.onFavoriteChanged?.call();
        },
        icon: Icon(
          fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: 22,
          color: fav ? scheme.primary : scheme.outline,
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.music_note),
              title: Text(song.displayNameWOExt),
              subtitle: Text(_artist),
            ),
            ListTile(
              leading: const Icon(Icons.album_outlined),
              title: Text(song.album ?? 'Unknown album'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(_formatDuration(song.duration)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String get _artist {
    final a = song.artist;
    return (a == null || a == '<unknown>') ? 'Unknown artist' : a;
  }

  String _formatDuration(int? millis) {
    if (millis == null) return 'Unknown length';
    final d = Duration(milliseconds: millis);
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
