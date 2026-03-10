import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:deardays/features/book/data/models/book.dart';

class BookRepository {
  final SupabaseClient _client;

  BookRepository({required SupabaseClient client}) : _client = client;

  String get _userId => _client.auth.currentUser!.id;

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
    final map = book.toMap();
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
