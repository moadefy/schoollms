import 'package:sqflite/sqflite.dart';

class Timetable {
  final int id;
  final String teacherId;
  final String classId;
  final String timeSlot;
  final List<String> learnerIds;

  Timetable(
      {required this.id,
      required this.teacherId,
      required this.classId,
      required this.timeSlot,
      required this.learnerIds});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'classId': classId,
      'timeSlot': timeSlot,
      'learnerIds': learnerIds.join(','),
    };
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE timetables (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        teacherId TEXT,
        classId TEXT,
        timeSlot TEXT,
        learnerIds TEXT
      )
    ''');
  }
}
