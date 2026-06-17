import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:songhut/theme/app_theme.dart';

void main() {
  testWidgets('app theme builds and renders in light and dark', (tester) async {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(body: Center(child: Text('AudioMark'))),
        ),
      );
      expect(find.text('AudioMark'), findsOneWidget);
    }
  });

  test('themes are Material 3', () {
    expect(AppTheme.light.useMaterial3, true);
    expect(AppTheme.dark.useMaterial3, true);
  });
}
