import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:calculator/screen/gold_screen.dart';

void main() {
  testWidgets(
    'mode changes preserve inputs, settings persist but trade drafts do not',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GoldScreen())),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Example contract · Specifications unconfirmed'),
        findsOneWidget,
      );
      await tester.enterText(
        find.byKey(const ValueKey('gold-Balance')),
        '10000',
      );
      await tester.enterText(
        find.byKey(const ValueKey('gold-Risk percent')),
        '1',
      );
      await tester.enterText(
        find.byKey(const ValueKey('gold-Entry price')),
        '2000',
      );
      await tester.tap(find.text('P&L'));
      await tester.pumpAndSettle();
      expect(
        (tester.widget<TextField>(
          find.byKey(const ValueKey('gold-Entry price')),
        )).controller!.text,
        '2000',
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: GoldScreen())),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('gold-Balance')))
            .controller!
            .text,
        '10000',
      );
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('gold-Entry price')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );
}
