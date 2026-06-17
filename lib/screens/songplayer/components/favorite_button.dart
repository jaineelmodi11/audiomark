import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:songhut/services/prefs_service.dart';

/// A real, persisted favourite toggle for the current song.
class FavoriteButton extends StatefulWidget {
  const FavoriteButton({super.key, required this.songId});
  final int songId;

  @override
  State<FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool fav = PrefsService.instance.isFavorite(widget.songId);
    return IconButton(
      tooltip: fav ? 'Remove from favourites' : 'Add to favourites',
      onPressed: () async {
        HapticFeedback.lightImpact();
        await PrefsService.instance.toggleFavorite(widget.songId);
        if (mounted) setState(() {});
      },
      icon: Icon(
        fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        color: fav ? scheme.primary : scheme.onSurfaceVariant,
      ),
    );
  }
}
