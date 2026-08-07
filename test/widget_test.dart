import 'dart:convert';

import 'package:boltaethergame/core/models.dart';
import 'package:boltaethergame/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('every bundled bolt parses into a usable model', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final raw = await rootBundle.loadString('assets/content/bolts.json');
    final bolts = (jsonDecode(raw) as Map<String, dynamic>)['bolts'] as List;

    expect(bolts.length, greaterThan(50));
    final ids = <String>{};
    for (final item in bolts) {
      final bolt = Bolt.fromJson(item as Map<String, dynamic>);
      expect(bolt.text.trim(), isNotEmpty);
      expect(ids.add(bolt.id), isTrue, reason: 'duplicate id ${bolt.id}');
      if (bolt.kind == BoltKind.collage) {
        expect(bolt.words, isNotEmpty);
      }
    }
  });

  test('community seed posts keep the poster out of the quote attribution', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final raw = await rootBundle.loadString('assets/content/community.json');
    final posts = (jsonDecode(raw) as Map<String, dynamic>)['posts'] as List;

    for (final item in posts) {
      final post = CommunityPost.fromSeed(item as Map<String, dynamic>, DateTime.now());
      expect(post.author, isNotEmpty);
      expect(post.bolt.author, isNull);
    }
  });

  testWidgets('progress bar fills from the left and never overflows',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 200, child: AetherProgressBar(value: 0.5)),
          ),
        ),
      ),
    );

    final fill = tester.widget<Align>(
      find.descendant(of: find.byType(AetherProgressBar), matching: find.byType(Align)),
    );
    expect(fill.alignment, Alignment.centerLeft);

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(width: 200, child: AetherProgressBar(value: 4)),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading label cycles Loading. -> Loading.. -> Loading...',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: DottedLoadingText()))),
    );
    expect(find.text('Loading'), findsOneWidget);
    expect(find.text('.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('..'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('...'), findsOneWidget);
  });
}
