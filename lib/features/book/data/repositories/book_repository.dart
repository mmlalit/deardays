import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/features/book/data/models/book.dart';
import 'package:deardays/features/book/data/models/book_page.dart';

class BookRepository {
  final SupabaseClient _client;

  BookRepository({required SupabaseClient client}) : _client = client;

  String get _userId => _client.auth.currentUser?.id ?? (throw StateError('Not authenticated'));

  Future<List<Book>> getBooks() async {
    final response = await _client
        .from('books')
        .select()
        .eq('user_id', _userId)
        .order('sort_order', ascending: true)
        .order('start_date', ascending: false);

    return (response as List<dynamic>)
        .map((row) => Book.fromMap(row as Map<String, dynamic>))
        .toList();
  }

  Future<Book> getBook(String id) async {
    final response = await _client
        .from('books')
        .select()
        .eq('id', id)
        .eq('user_id', _userId)
        .single();

    return Book.fromMap(response);
  }

  Future<Book> createBook(Book book) async {
    final map = Map<String, dynamic>.from(book.toMap());
    map.remove('id');
    map.remove('created_at');
    map.remove('updated_at');
    map['user_id'] = _userId;

    final response = await _client
        .from('books')
        .insert(map)
        .select()
        .single();

    return Book.fromMap(response);
  }

  Future<Book> updateBook(Book book) async {
    final map = <String, dynamic>{
      'title': book.title,
      'cover_color': book.coverColor,
      'writing_style': book.writingStyle,
      'creation_approach': book.creationApproach,
      'cover_image_url': book.coverImageUrl,
      'start_date': book.startDate.toIso8601String().split('T').first,
      'end_date': book.endDate?.toIso8601String().split('T').first,
      'sort_order': book.sortOrder,
      'updated_at': DateTime.now().toIso8601String(),
    };

    final response = await _client
        .from('books')
        .update(map)
        .eq('id', book.id)
        .eq('user_id', _userId)
        .select()
        .single();

    return Book.fromMap(response);
  }

  Future<void> deleteBook(String id) async {
    await _client
        .from('books')
        .delete()
        .eq('id', id)
        .eq('user_id', _userId);
  }

  /// Fetches a window of AI-generated weekly narrative pages for a book.
  ///
  /// [offset] is the 0-based starting row; [limit] is the page count per window.
  /// Default window of 10 pages balances memory use and swipe smoothness.
  /// The reader should pre-fetch the next window when the user reaches page
  /// [offset + limit - 3] (3-page look-ahead).
  Future<List<WeeklyNarrativeBookPage>> getWeeklyPages(
    String bookId, {
    int offset = 0,
    int limit = 10,
  }) async {
    final response = await _client
        .from('pages')
        .select('id, content, week_start, page_number, word_count, photos')
        .eq('book_id', bookId)
        .order('week_start', ascending: true)
        .order('page_number', ascending: true)
        .range(offset, offset + limit - 1);

    return (response as List<dynamic>)
        .map((row) =>
            WeeklyNarrativeBookPage.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Returns the total number of AI-generated pages for a book.
  /// Uses COUNT(*) — fetches zero rows, just the count.
  Future<int> getWeeklyPagesCount(String bookId) async {
    final response = await _client
        .from('pages')
        .select()
        .eq('book_id', bookId)
        .count(CountOption.exact);
    return response.count;
  }

  /// Updates the photo assignments for a single page (user edits).
  Future<void> updatePagePhotos(String pageId, List<PagePhoto> photos) async {
    await _client
        .from('pages')
        .update({'photos': photos.map((p) => p.toJson()).toList()})
        .eq('id', pageId);
  }

  /// Ensures a default book exists for the current period based on organization setting.
  Future<Book> ensureDefaultBook(String organization) async {
    final books = await getBooks();
    if (books.isNotEmpty) return books.first;

    final now = DateTime.now();
    late DateTime startDate;
    late DateTime endDate;
    late String title;

    switch (organization) {
      case 'monthly':
        startDate = DateTime(now.year, now.month, 1);
        endDate = DateTime(now.year, now.month + 1, 0);
        title = '${_monthName(now.month)} ${now.year}';
        break;
      case 'quarterly':
        final quarter = ((now.month - 1) ~/ 3) + 1;
        startDate = DateTime(now.year, (quarter - 1) * 3 + 1, 1);
        endDate = DateTime(now.year, quarter * 3 + 1, 0);
        title = 'Q$quarter ${now.year}';
        break;
      case 'manual':
        startDate = DateTime(now.year, 1, 1);
        title = 'My Journal';
        return createBook(Book(
          id: '',
          userId: _userId,
          title: title,
          startDate: startDate,
          createdAt: now,
          updatedAt: now,
        ));
      default: // yearly
        startDate = DateTime(now.year, 1, 1);
        endDate = DateTime(now.year, 12, 31);
        title = '${now.year}';
    }

    return createBook(Book(
      id: '',
      userId: _userId,
      title: title,
      startDate: startDate,
      endDate: endDate,
      createdAt: now,
      updatedAt: now,
    ));
  }

  /// Links [chapterIds] to [bookId] for a thematic book.
  ///
  /// Note: this is a single batch UPDATE — not a true DB transaction. If the
  /// call is interrupted, some chapters may remain unlinked. Callers should
  /// handle errors and retry or surface the failure to the user.
  Future<void> linkChaptersToBook(String bookId, List<String> chapterIds) async {
    if (chapterIds.isEmpty) return;
    try {
      await _client
          .from('chapters')
          .update({'book_id': bookId})
          .inFilter('id', chapterIds)
          .eq('user_id', _userId);
    } catch (e) {
      debugPrint('[BookRepository] linkChaptersToBook failed: $e');
      rethrow;
    }
  }

  /// Creates a single auto-chapter for a chronological book.
  Future<void> createChronologicalChapter(String bookId, String bookTitle) async {
    await _client.from('chapters').insert({
      'user_id': _userId,
      'book_id': bookId,
      'title': bookTitle,
      'chapter_number': 1,
      'start_date': DateTime.now().toIso8601String().split('T').first,
    });
  }

  /// Uploads a cover image to Supabase Storage and returns the public URL.
  Future<String> uploadCoverImage(String bookId, File imageFile) async {
    final ext = imageFile.path.split('.').last;
    final path = '$_userId/$bookId.$ext';

    await _client.storage.from('user-covers').upload(
          path,
          imageFile,
          fileOptions: const FileOptions(upsert: true),
        );

    return _client.storage.from('user-covers').getPublicUrl(path);
  }

  String _monthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    return months[month - 1];
  }
}
