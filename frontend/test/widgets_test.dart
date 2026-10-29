import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:medminder/widgets/common.dart';

void main() {
  testWidgets('StatusChip shows a readable label', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body: StatusChip('missed'))));
    expect(find.text('Missed'), findsOneWidget);
  });

  testWidgets('AdherenceRing shows completed / total', (tester) async {
    await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AdherenceRing(done: 2, total: 3))));
    expect(find.text('2/3'), findsOneWidget);
  });

  testWidgets('ErrorView offers a retry action', (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: ErrorView(message: 'Offline', onRetry: () => retried = true))));
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
  });
}
