import 'package:sqflite/sqflite.dart';

class Question {
  final String id;
  final String?
      timetableId; // Changed to String? to align with Timetable.id (UUID)
  final String classId;
  final String? assessmentId; // New field to link to an assessment
  String
      content; // Changed to non-final to allow updates, as per previous fixes
  final int? pdfPage; // Null for non-PDF questions

  Question({
    required this.id,
    this.timetableId,
    required this.classId,
    this.assessmentId,
    required this.content,
    this.pdfPage,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timetableId': timetableId, // Optional, can be null, now String
      'classId': classId,
      'assessmentId': assessmentId, // New field
      'content': content,
      'pdfPage': pdfPage,
    };
  }

  factory Question.fromMap(Map<String, dynamic> map) {
    return Question(
      id: map['id'] as String,
      timetableId: map['timetableId'] as String?, // Changed to String?
      classId: map['classId'] as String,
      assessmentId: map['assessmentId'] as String?,
      content: map['content'] as String,
      pdfPage: map['pdfPage'] as int?,
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE questions (
        id TEXT PRIMARY KEY,
        timetableId TEXT, -- Changed to TEXT to store UUID, optional
        classId TEXT NOT NULL,
        assessmentId TEXT, -- New column, optional
        content TEXT NOT NULL,
        pdfPage INTEGER
      )
    ''');
  }
}
