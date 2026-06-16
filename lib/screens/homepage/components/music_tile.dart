import 'package:flutter/material.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:songhut/utils/extensions/SongModelExtension.dart';

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
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: QueryArtworkWidget(
          id: songModel.id,
          type: ArtworkType.AUDIO,
          artworkHeight: 48,
          artworkWidth: 48,
          artworkBorder: BorderRadius.circular(8),
          artworkFit: BoxFit.cover,
          nullArtworkWidget: Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.music_note, color: scheme.onPrimaryContainer),
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
