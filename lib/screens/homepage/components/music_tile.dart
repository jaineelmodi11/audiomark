import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:songhut/utils/extensions/song_model_extension.dart';
import 'package:songhut/utils/song_color.dart';

class MusicTile extends StatelessWidget {
  final SongModel songModel;
  final VoidCallback? onTap;

  const MusicTile({
    required this.songModel,
    this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Hero(
        tag: 'artwork_${songModel.id}',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: QueryArtworkWidget(
            id: songModel.id,
            type: ArtworkType.AUDIO,
            artworkHeight: 52,
            artworkWidth: 52,
            artworkBorder: BorderRadius.circular(12),
            artworkFit: BoxFit.cover,
            nullArtworkWidget: Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: songGradientForId(songModel.id),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.music_note_rounded,
                  color: Colors.white, size: 24),
            ),
          ),
        ),
      ),
      title: Text(
        songModel.displayNameWOExt,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        songModel.additionalSongInfo,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => _showDetails(context),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.music_note),
              title: Text(songModel.displayNameWOExt),
              subtitle: Text(_artist),
            ),
            ListTile(
              leading: const Icon(Icons.album_outlined),
              title: Text(songModel.album ?? 'Unknown album'),
            ),
            ListTile(
              leading: const Icon(Icons.schedule),
              title: Text(_formatDuration(songModel.duration)),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  String get _artist {
    final a = songModel.artist;
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
