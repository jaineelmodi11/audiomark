import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songhut/utils/song_color.dart';

void main() {
  group('songColorForId', () {
    test('is deterministic for the same id', () {
      expect(songColorForId(42), songColorForId(42));
      expect(songColorForId(1000000031), songColorForId(1000000031));
    });

    test('different ids generally map to different hues', () {
      final colors = {for (final id in [1, 2, 3, 4, 5, 6, 7, 8]) songColorForId(id)};
      // With 8 distinct ids we expect several distinct colours, not all the same.
      expect(colors.length, greaterThan(4));
    });

    test('handles negative ids without throwing', () {
      expect(() => songColorForId(-17), returnsNormally);
    });

    test('returns fully opaque colours', () {
      expect(songColorForId(123).a, 1.0);
    });
  });

  group('songGradientForId', () {
    test('returns two stops, lighter then base', () {
      final g = songGradientForId(7);
      expect(g.length, 2);
      final lighter = HSLColor.fromColor(g[0]).lightness;
      final base = HSLColor.fromColor(g[1]).lightness;
      expect(lighter, greaterThanOrEqualTo(base));
    });

    test('base stop matches songColorForId', () {
      expect(songGradientForId(99)[1], songColorForId(99));
    });
  });
}
