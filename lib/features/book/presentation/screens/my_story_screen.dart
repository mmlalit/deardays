import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:deardays/core/theme/app_colors.dart';
import 'package:deardays/core/providers/app_providers.dart';
import 'package:deardays/features/book/data/models/book.dart';
import 'package:deardays/features/book/presentation/screens/life_book_view.dart';

class MyStoryScreen extends ConsumerWidget {
  final String bookId;

  const MyStoryScreen({super.key, required this.bookId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final booksAsync = ref.watch(booksProvider);

    return booksAsync.when(
      data: (books) {
        final book = books.where((b) => b.id == bookId).firstOrNull;
        if (book == null) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Book not found',
                      style:
                          GoogleFonts.inter(color: AppColors.textSecondary)),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/book'),
                    child: const Text('Back to Library'),
                  ),
                ],
              ),
            ),
          );
        }
        return _buildContent(context, book);
      },
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => context.go('/book'),
            child: const Text('Back to Library'),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Book book) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, book),
            const SizedBox(height: 4),
            const Expanded(child: LifeBookView()),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Book book) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go('/book'),
            child: Icon(
              Icons.arrow_back_ios,
              size: 18,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              book.title.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.5,
                color: AppColors.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
