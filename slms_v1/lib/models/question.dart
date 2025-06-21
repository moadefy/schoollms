import 'package:sqflite/sqflite.dart';

class Question {
  final String id;
  final int timetableId; // Changed from String to int
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
      'timetableId': timetableId, // Changed from String to int
      'classId': classId,
      'content': content,
      'pdfPage': pdfPage,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] as String,
      timetableId: map['timetableId'] as int,
      classId: map['classId'] as String,
      content: map['content'] as String,
      pdfPage: map['pdfPage'] as int?,
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE questions (
        id TEXT PRIMARY KEY,
        timetableId INTEGER, -- Changed from TEXT to INTEGER
        classId TEXT,
        content TEXT,
        pdfPage INTEGER
      )
    ''');
  }
}
