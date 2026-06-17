import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:songhut/services/prefs_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PrefsService.instance.init();
  });

  group('favorites', () {
    test('toggles on and off, and persists', () async {
      final p = PrefsService.instance;
      expect(p.isFavorite(1), false);
      await p.toggleFavorite(1);
      expect(p.isFavorite(1), true);
      expect(p.favorites, contains(1));
      await p.toggleFavorite(1);
      expect(p.isFavorite(1), false);
    });
  });

  group('recently played', () {
    test('most recent first, de-duplicated', () async {
      final p = PrefsService.instance;
      await p.addRecent(1);
      await p.addRecent(2);
      await p.addRecent(1); // re-adding moves it to front
      expect(p.recentIds.first, 1);
      expect(p.recentIds.where((e) => e == 1).length, 1);
    });

    test('caps history at 20 entries', () async {
      final p = PrefsService.instance;
      for (int i = 0; i < 30; i++) {
        await p.addRecent(i);
      }
      expect(p.recentIds.length, 20);
      expect(p.recentIds.first, 29); // newest
    });
  });

  group('per-song speed and loop', () {
    test('speed defaults to 1.0 and round-trips', () async {
      final p = PrefsService.instance;
      expect(p.getSpeed(5), 1.0);
      await p.setSpeed(5, 0.75);
      expect(p.getSpeed(5), 0.75);
    });

    test('loop is null until set, then round-trips', () async {
      final p = PrefsService.instance;
      expect(p.getLoop(5), isNull);
      await p.setLoop(5, 10, 30);
      expect(p.getLoop(5), [10, 30]);
    });
  });
}
