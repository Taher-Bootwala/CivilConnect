// CivilHand Widget Smoke Test
// Verifies mandatory account creation gate and shell tabs

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:civilhand/main.dart';

void main() {
  testWidgets('CivilHand shows Account Creation gate when not authenticated', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CivilHandApp(initialAuthenticated: false)));
    await tester.pumpAndSettle();

    // Verify mandatory account creation screen is shown first
    expect(find.text('Create an Account'), findsWidgets);
    expect(find.text('Choose Your Account Type'), findsOneWidget);
    expect(find.text('Customer'), findsOneWidget);
    expect(find.text('Professional'), findsOneWidget);
  });

  testWidgets('CivilHand App shell smoke test when authenticated', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: CivilHandApp(initialAuthenticated: true)));
    await tester.pumpAndSettle();

    // Verify main bottom navigation tabs are present
    expect(find.text('Customer App'), findsOneWidget);
    expect(find.text('Worker Console'), findsOneWidget);
    expect(find.text('Admin & Ledger'), findsOneWidget);
  });
}
