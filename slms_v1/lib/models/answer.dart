import 'package:sqflite/sqflite.dart';
import 'dart:convert';

class Answer {
  final String id;
  final String questionId;
  final String learnerId;
  final List<Map<String, dynamic>> strokes; // Canvas strokes
  final List<Map<String, dynamic>> assets; // Canvas assets (images/PDFs)
  final int? submitted_at; // Nullable submission timestamp
  double? score; // Optional score, default to null
  String? remarks; // Optional remarks, default to null
  final String? slotId; // New field to link to timetable_slot

  Answer({
    required this.id,
    required this.questionId,
    required this.learnerId,
    required this.strokes,
    required this.assets,
    this.submitted_at,
    this.score = 0.0, // Default to 0.0 if not provided
    this.remarks = '', // Default to empty string if not provided
    this.slotId, // Added as optional
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
      score: (map['score'] != null) ? map['score'] as double : 0.0,
      remarks: map['remarks'] as String? ?? '',
      slotId: map['slotId'] as String?, // Added to fromMap
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
      'score': score,
      'remarks': remarks,
      'slotId': slotId, // Added to map
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
          submitted_at INTEGER,
          score REAL, -- Using REAL for double/float values
          remarks TEXT,
          slotId TEXT -- Added column for slot association
        )
      ''');
    } catch (e) {
      throw Exception('Failed to create answers table: $e');
    }
  }
}
