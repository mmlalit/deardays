import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:deardays/core/theme/app_theme.dart';
import 'package:deardays/features/story/presentation/screens/story_viewer_screen.dart';
import 'package:deardays/features/story/presentation/providers/story_provider.dart';
import 'package:deardays/features/story/data/models/life_story.dart';
import 'package:deardays/core/providers/app_providers.dart';

import '../helpers/mock_providers.dart';

void main() {
  setUpTestEnv();

  Widget buildWithState(StoryState initialState) {
    return ProviderScope(
      overrides: [
        ...authenticatedOverrides(),
        storyFamilyProvider(ReflectionPeriod.weekly).overrideWith(
          (ref) => _FakeStoryNotifier(initialState),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const StoryViewerScreen(period: ReflectionPeriod.weekly),
      ),
    );
  }

  group('StoryViewerScreen', () {
    testWidgets('shows loading state with progress', (tester) async {
      await tester.pumpWidget(buildWithState(
        const StoryState(status: StoryStatus.generating, progress: 0.5),
      ));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Crafting your story\u2026'), findsOneWidget);
      expect(find.text('Reading your memories'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });

    testWidgets('shows error state with retry button', (tester) async {
      await tester.pumpWidget(buildWithState(
        const StoryState(
          status: StoryStatus.error,
          errorMessage: 'Network error occurred',
        ),
      ));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Network error occurred'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('default error message when errorMessage is null',
        (tester) async {
      await tester.pumpWidget(buildWithState(
        const StoryState(status: StoryStatus.error),
      ));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Something went wrong'), findsOneWidget);
    });

    // Note: "available" state tests (page dots, close button, stats) are
    // skipped because the quote card uses GoogleFonts.newsreader with
    // fontStyle: italic + fontWeight: w600 → Newsreader-SemiBoldItalic,
    // which is not bundled in assets/fonts.
  });
}

class _FakeStoryNotifier extends StoryNotifier {
  _FakeStoryNotifier(StoryState initialState) : super(_FakeRef()) {
    state = initialState;
  }

  @override
  Future<void> generateStory() async {
    // No-op in tests
  }
}

/// Minimal Ref stub — StoryNotifier only uses ref in generateStory which we override.
class _FakeRef implements Ref {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
