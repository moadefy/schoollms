import 'package:sqflite/sqflite.dart';

class LearnerTimetable {
  final String id;
  final String learnerId;
  final String classId;
  final String timeSlot;

  LearnerTimetable({
    required this.id,
    required this.learnerId,
    required this.classId,
    required this.timeSlot,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'learnerId': learnerId,
        'classId': classId,
        'timeSlot': timeSlot,
      };

  static LearnerTimetable fromMap(Map<String, dynamic> map) {
    return LearnerTimetable(
      id: map['id'] as String? ?? '',
      learnerId: map['learnerId'] as String? ?? '',
      classId: map['classId'] as String? ?? '',
      timeSlot: map['timeSlot'] as String? ?? '',
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE learner_timetables (
        id TEXT PRIMARY KEY,
        learnerId TEXT,
        classId TEXT,
        timeSlot TEXT
      )
    ''');
  }
}
