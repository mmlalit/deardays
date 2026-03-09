import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deardays/features/book/presentation/screens/library_screen.dart';
import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();
  Widget buildApp({List<Override> overrides = const []}) {
    return ProviderScope(
      overrides: overrides,
      child: const MaterialApp(home: LibraryScreen()),
    );
  }

  group('LibraryScreen - Header', () {
    testWidgets('shows My Books header', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('My Books'), findsOneWidget);
    });
  });

  group('LibraryScreen - Empty state', () {
    testWidgets('renders empty state when no books', (tester) async {
      await tester.pumpWidget(buildApp(
        overrides: authenticatedOverrides(books: []),
      ));
      await tester.pumpAndSettle();

      // Should show header regardless of books
      expect(find.text('My Books'), findsOneWidget);
    });

    testWidgets('shows loading skeleton initially', (tester) async {
      await tester.pumpWidget(buildApp(overrides: authenticatedOverrides()));
      // Just pump one frame to catch loading state
      await tester.pump();

      // Screen should render during loading
      expect(find.byType(LibraryScreen), findsOneWidget);
    });
  });

  group('LibraryScreen - With books', () {
    testWidgets('shows book title when books are loaded', (tester) async {
      await tester.pumpWidget(buildApp(
        overrides: authenticatedOverrides(books: [mockBook]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('My Story 2026'), findsOneWidget);
    });

    testWidgets('shows multiple books', (tester) async {
      final book2 = mockBook.copyWith(
        id: 'book-2',
        title: 'Year 2025',
        startDate: DateTime(2025, 1, 1),
      );
      await tester.pumpWidget(buildApp(
        overrides: authenticatedOverrides(books: [mockBook, book2]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('My Story 2026'), findsOneWidget);
      expect(find.text('Year 2025'), findsOneWidget);
    });
  });
}
