import 'dart:convert'; // Added for jsonEncode and jsonDecode
import 'package:sqflite/sqflite.dart'; // Added for Database

class Assessment {
  final String id;
  final List<String> classIds; // Multiple classes can be associated
  final String type; // activity, test, homework, assignment, exam
  final int? timerSeconds; // For test/exam
  final DateTime? closeTime; // Auto-close time
  final List<String> questionIds;

  Assessment({
    required this.id,
    required this.classIds,
    required this.type,
    this.timerSeconds,
    this.closeTime,
    required this.questionIds,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'classIds': jsonEncode(classIds), // Now recognized with import
        'type': type,
        'timerSeconds': timerSeconds,
        'closeTime': closeTime?.millisecondsSinceEpoch,
        'questionIds': jsonEncode(questionIds), // Now recognized with import
      };

  static Future<void> createTable(Database db) async {
    // Database now recognized
    await db.execute('''
      CREATE TABLE assessments (
        id TEXT PRIMARY KEY,
        classIds TEXT NOT NULL,
        type TEXT NOT NULL,
        timerSeconds INTEGER,
        closeTime INTEGER,
        questionIds TEXT NOT NULL
      )
    ''');
  }

  factory Assessment.fromMap(Map<String, dynamic> map) {
    return Assessment(
      id: map['id'] as String,
      classIds: (jsonDecode(map['classIds'] as String) as List)
          .cast<String>(), // Now recognized
      type: map['type'] as String,
      timerSeconds: map['timerSeconds'] as int?,
      closeTime: map['closeTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['closeTime'] as int)
          : null,
      questionIds: (jsonDecode(map['questionIds'] as String) as List)
          .cast<String>(), // Now recognized
    );
  }
}
