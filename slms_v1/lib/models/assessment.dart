import 'dart:convert'; // For jsonEncode and jsonDecode
import 'package:sqflite/sqflite.dart'; // For Database

class Assessment {
  final String id;
  final List<String> classIds; // Multiple classes can be associated
  final String type; // activity, test, homework, assignment, exam
  final int? timerSeconds; // For test/exam
  final DateTime? closeTime; // Auto-close time
  final List<String> questionIds;
  final String? slotId; // New field to link to timetable_slot

  Assessment({
    required this.id,
    required this.classIds,
    required this.type,
    this.timerSeconds,
    this.closeTime,
    required this.questionIds,
    this.slotId, // Added as optional
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'classIds': jsonEncode(classIds),
        'type': type,
        'timerSeconds': timerSeconds,
        'closeTime': closeTime?.millisecondsSinceEpoch,
        'questionIds': jsonEncode(questionIds),
        'slotId': slotId, // Added to map
      };

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE assessments (
        id TEXT PRIMARY KEY,
        classIds TEXT NOT NULL,
        type TEXT NOT NULL,
        timerSeconds INTEGER,
        closeTime INTEGER,
        questionIds TEXT NOT NULL,
        slotId TEXT -- Added column for slot association
      )
    ''');
  }

  factory Assessment.fromMap(Map<String, dynamic> map) {
    return Assessment(
      id: map['id'] as String,
      classIds: (jsonDecode(map['classIds'] as String) as List).cast<String>(),
      type: map['type'] as String,
      timerSeconds: map['timerSeconds'] as int?,
      closeTime: map['closeTime'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['closeTime'] as int)
          : null,
      questionIds:
          (jsonDecode(map['questionIds'] as String) as List).cast<String>(),
      slotId: map['slotId'] as String?, // Added to fromMap
    );
  }
}
