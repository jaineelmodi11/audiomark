import 'package:flutter/material.dart';

/// A deterministic, tasteful colour identity for a song.
///
/// Most audio in this app is user-uploaded mp3/mp4 with **no embedded album
/// art**, so we derive a consistent muted hue from the MediaStore id. The same
/// song always maps to the same Apple-like colour, used for placeholders and
/// the player's adaptive gradient. Real embedded artwork overrides this.
Color songColorForId(int id) {
  // Spread sequential ids across the wheel; keep saturation/lightness moderate
  // so the result is refined rather than neon.
  final hue = ((id.abs() * 47) % 360).toDouble();
  return HSLColor.fromAHSL(1, hue, 0.42, 0.56).toColor();
}

/// Two soft stops (lighter -> base) for a placeholder gradient.
List<Color> songGradientForId(int id) {
  final HSLColor base = HSLColor.fromColor(songColorForId(id));
  final Color light =
      base.withLightness((base.lightness + 0.12).clamp(0.0, 1.0)).toColor();
  return [light, base.toColor()];
}
