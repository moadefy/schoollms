import 'package:sqflite/sqflite.dart';

class Learner {
  final String id;
  final String name;
  final String grade;
  String?
      timetableId; // Can link to a unique learner timetable or slot aggregation

  Learner({
    required this.id,
    required this.name,
    required this.grade,
    this.timetableId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'grade': grade,
      'timetableId': timetableId,
    };
  }

  factory Learner.fromMap(Map<String, dynamic> map) {
    return Learner(
      id: map['id'] as String,
      name: map['name'] as String,
      grade: map['grade'] as String,
      timetableId: map['timetableId'] as String?,
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE learners (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        grade TEXT NOT NULL,
        timetableId TEXT,
        FOREIGN KEY (timetableId) REFERENCES timetables(id) ON DELETE SET NULL
      )
    ''');
  }
}
