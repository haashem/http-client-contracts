import 'package:flutter_test/flutter_test.dart';
import 'package:example/app/fitness_companion_app.dart';

void main() {
  testWidgets('shows restore splash then opens home', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FitnessCompanionApp());

    expect(find.text('Restoring session...'), findsOneWidget);

    await tester.pumpAndSettle();

    expect(find.textContaining('Fitness Companion'), findsOneWidget);
  });
}
