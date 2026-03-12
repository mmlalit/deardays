import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:deardays/features/auth/presentation/screens/pin_screen.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  Widget buildApp({PinMode mode = PinMode.setup}) {
    // Wrap in a MediaQuery with a tall surface to avoid overflow
    return buildTestApp(
      MediaQuery(
        data: const MediaQueryData(size: Size(400, 900)),
        child: PinScreen(mode: mode),
      ),
    );
  }

  group('PinScreen - Structure', () {
    testWidgets('renders without crash', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(PinScreen), findsOneWidget);
    });

    testWidgets('shows Create PIN title in setup mode', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(buildApp(mode: PinMode.setup));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Create PIN'), findsOneWidget);
    });

    testWidgets('shows Enter PIN title in verify mode', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(buildApp(mode: PinMode.verify));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Enter PIN'), findsOneWidget);
    });

    testWidgets('shows number pad digits 0-9', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(buildApp());
      await tester.pump(const Duration(milliseconds: 500));
      for (int i = 0; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }
    });

    testWidgets('shows subtitle text', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());
      await tester.pumpWidget(buildApp(mode: PinMode.setup));
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('Enter a 4-digit PIN'), findsOneWidget);
    });
  });
}
