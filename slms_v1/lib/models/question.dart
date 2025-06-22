import 'package:sqflite/sqflite.dart';

class Question {
  final String id;
  final String?
      timetableId; // Changed to String? to align with Timetable.id (UUID)
  final String classId;
  final String? assessmentId; // Links to an assessment
  String content; // Non-final to allow updates
  final int? pdfPage; // Null for non-PDF questions
  final String? slotId; // New field to link to timetable_slot

  Question({
    required this.id,
    this.timetableId,
    required this.classId,
    this.assessmentId,
    required this.content,
    this.pdfPage,
    this.slotId, // Added as optional
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'timetableId': timetableId, // Optional, can be null
      'classId': classId,
      'assessmentId': assessmentId, // Existing field
      'content': content,
      'pdfPage': pdfPage,
      'slotId': slotId, // Added to map
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
      slotId: map['slotId'] as String?, // Added to fromMap
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE questions (
        id TEXT PRIMARY KEY,
        timetableId TEXT, -- TEXT to store UUID, optional
        classId TEXT NOT NULL,
        assessmentId TEXT, -- Optional, links to assessment
        content TEXT NOT NULL,
        pdfPage INTEGER,
        slotId TEXT -- Added column for slot association
      )
    ''');
  }
}
