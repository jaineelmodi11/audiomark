import 'package:flutter_test/flutter_test.dart';
import 'package:songhut/services/player_host.dart';

void main() {
  group('PlayerHost.isSubRange', () {
    test('full-track range is not a section (lets the queue auto-advance)',
        () {
      expect(PlayerHost.isSubRange(0, 35, 35), false);
      // Slider seconds are truncated, so allow the ±0.5 s tolerance band.
      expect(PlayerHost.isSubRange(0, 34.8, 35), false);
    });

    test('trimmed start or end is a section', () {
      expect(PlayerHost.isSubRange(5, 35, 35), true);
      expect(PlayerHost.isSubRange(0, 19, 35), true);
      expect(PlayerHost.isSubRange(5, 19, 35), true);
    });

    test('degenerate inputs are never a section', () {
      expect(PlayerHost.isSubRange(0, 0, 35), false); // empty range
      expect(PlayerHost.isSubRange(19, 5, 35), false); // inverted
      expect(PlayerHost.isSubRange(0, 19, null), false); // no duration yet
      expect(PlayerHost.isSubRange(0, 19, 0), false);
    });
  });
}
