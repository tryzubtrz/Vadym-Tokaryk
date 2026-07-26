import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mymasya_ai/data/models/needs_model.dart';
import 'package:mymasya_ai/features/home/widgets/tom_needs_pips.dart';

void main() {
  testWidgets('hides when needs are healthy', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TomNeedsPips(needs: NeedsModel()),
        ),
      ),
    );
    expect(find.byType(Icon), findsNothing);
  });

  testWidgets('shows pip when hunger critical', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TomNeedsPips(
            needs: NeedsModel(hunger: 10),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.restaurant_rounded), findsOneWidget);
  });
}
