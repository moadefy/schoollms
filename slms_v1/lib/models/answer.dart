import 'package:sqflite/sqflite.dart';
import 'dart:convert';

class Answer {
  final String id;
  final String questionId;
  final String learnerId;
  final List<Map<String, dynamic>> strokes; // Canvas strokes
  final List<Map<String, dynamic>> assets; // Canvas assets (images/PDFs)
  final int? submitted_at; // Nullable submission timestamp

  Answer({
    required this.id,
    required this.questionId,
    required this.learnerId,
    required this.strokes,
    required this.assets,
    this.submitted_at,
  });

  // Factory constructor to create Answer from a map (e.g., database result)
  factory Answer.fromMap(Map<String, dynamic> map) {
    return Answer(
      id: map['id'] as String,
      questionId: map['questionId'] as String,
      learnerId: map['learnerId'] as String,
      strokes: (jsonDecode(map['strokes'] as String) as List)
          .cast<Map<String, dynamic>>(),
      assets: (jsonDecode(map['assets'] as String) as List)
          .cast<Map<String, dynamic>>(),
      submitted_at: map['submitted_at'] as int?,
    );
  }

  // Convert Answer to a map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'questionId': questionId,
      'learnerId': learnerId,
      'strokes': jsonEncode(strokes),
      'assets': jsonEncode(assets),
      'submitted_at': submitted_at,
    };
  }

  // Create the answers table in the database
  static Future<void> createTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE answers (
          id TEXT PRIMARY KEY,
          questionId TEXT NOT NULL,
          learnerId TEXT NOT NULL,
          strokes TEXT NOT NULL,
          assets TEXT NOT NULL,
          submitted_at INTEGER
        )
      ''');
    } catch (e) {
      throw Exception('Failed to create answers table: $e');
    }
  }
}
