import 'package:sqflite/sqflite.dart';

class TimetableSlot {
  final String id;
  final String classId;
  final String timeSlot;
  final List<String> learnerIds;

  TimetableSlot({
    required this.id,
    required this.classId,
    required this.timeSlot,
    required this.learnerIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'classId': classId,
      'timeSlot': timeSlot,
      'learnerIds': learnerIds.join(','),
    };
  }

  factory TimetableSlot.fromMap(Map<String, dynamic> map) {
    return TimetableSlot(
      id: map['id'] as String,
      classId: map['classId'] as String,
      timeSlot: map['timeSlot'] as String,
      learnerIds: (map['learnerIds'] as String).split(','),
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE timetable_slots (
        id TEXT PRIMARY KEY,
        classId TEXT,
        timeSlot TEXT,
        learnerIds TEXT,
        FOREIGN KEY (classId) REFERENCES classdata(id) ON DELETE SET NULL
      )
    ''');
  }
}
