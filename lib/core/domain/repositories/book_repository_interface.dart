import 'dart:io';

import 'package:deardays/features/book/data/models/book.dart';
import 'package:deardays/features/book/data/models/book_page.dart';

/// Contract for book data access.
///
/// Implementations: [BookRepository] (Supabase), test mocks.
abstract class IBookRepository {
  Future<List<Book>> getBooks();

  Future<Book?> getBook(String id);

  Future<Book> createBook(Book book);

  Future<Book?> updateBook(Book book);

  Future<void> deleteBook(String id);

  Future<List<WeeklyNarrativeBookPage>> getWeeklyPages(
    String bookId, {
    int offset = 0,
    int limit = 10,
  });

  Future<int> getWeeklyPagesCount(String bookId);

  Future<void> updatePagePhotos(String pageId, List<PagePhoto> photos);

  Future<Book> ensureDefaultBook(String organization);

  Future<void> linkChaptersToBook(String bookId, List<String> chapterIds);

  Future<void> createChronologicalChapter(String bookId, String bookTitle);

  Future<String> uploadCoverImage(String bookId, File imageFile);

  Future<String> getSignedCoverUrl(String storagePath);
}
