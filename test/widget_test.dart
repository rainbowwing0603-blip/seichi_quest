import 'package:flutter_test/flutter_test.dart';
import 'package:seichi_quest/main.dart';

void main() {
  testWidgets('Seichi Quest app can be created', (WidgetTester tester) async {
    await tester.pumpWidget(const SeichiQuestApp());

    expect(find.byType(SeichiQuestApp), findsOneWidget);
  });
}
