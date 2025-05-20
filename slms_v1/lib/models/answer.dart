import 'package:sqflite/sqflite.dart';

class Answer {
  final String id;
  final String questionId;
  final String learnerId;
  final String content; // JSON-encoded CanvasElement list (strokes/annotations)
  final int submitted_at;

  Answer({
    required this.id,
    required this.questionId,
    required this.learnerId,
    required this.content,
    required this.submitted_at,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionId': questionId,
      'learnerId': learnerId,
      'content': content,
      'submitted_at': submitted_at,
    };
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE answers (
        id TEXT PRIMARY KEY,
        questionId TEXT,
        learnerId TEXT,
        content TEXT,
        submitted_at INTEGER
      )
    ''');
  }
}
