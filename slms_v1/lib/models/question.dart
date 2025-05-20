import 'package:sqflite/sqflite.dart';

class Question {
  final String id;
  final String timetableId;
  final String classId;
  final String content; // JSON-encoded CanvasElement list
  final int? pdfPage; // Null for non-PDF questions

  Question({
    required this.id,
    required this.timetableId,
    required this.classId,
    required this.content,
    this.pdfPage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timetableId': timetableId,
      'classId': classId,
      'content': content,
      'pdfPage': pdfPage,
    };
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE questions (
        id TEXT PRIMARY KEY,
        timetableId TEXT,
        classId TEXT,
        content TEXT,
        pdfPage INTEGER
      )
    ''');
  }
}
