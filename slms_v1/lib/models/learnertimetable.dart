import 'package:sqflite/sqflite.dart';

class LearnerTimetable {
  final String id; // Changed from int to String for UUID
  final String learnerId;
  final String classId;
  final String timeSlot;
  final String status;
  final String? attendance;
  final int? attendanceDate;

  LearnerTimetable({
    required this.id,
    required this.learnerId,
    required this.classId,
    required this.timeSlot,
    required this.status,
    this.attendance,
    this.attendanceDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, // Store as string
      'learnerId': learnerId,
      'classId': classId,
      'timeSlot': timeSlot,
      'status': status,
      'attendance': attendance,
      'attendanceDate': attendanceDate,
    };
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE learner_timetables (
        id TEXT PRIMARY KEY, -- Changed to TEXT PRIMARY KEY for UUID
        learnerId TEXT NOT NULL,
        classId TEXT NOT NULL,
        timeSlot TEXT NOT NULL,
        status TEXT NOT NULL,
        attendance TEXT,
        attendanceDate INTEGER,
        modified_at INTEGER DEFAULT (CAST((julianday('now') - 2440587.5)*86400000 AS INTEGER))
      )
    ''');
    await db.execute('''
      CREATE TRIGGER update_learner_timetables_modified_at
      AFTER UPDATE ON learner_timetables
      BEGIN
        UPDATE learner_timetables SET modified_at = CAST((julianday('now') - 2440587.5)*86400000 AS INTEGER) WHERE id = NEW.id;
      END;
    ''');
  }

  factory LearnerTimetable.fromMap(Map<String, dynamic> map) {
    return LearnerTimetable(
      id: map['id'] as String, // Cast id as String
      learnerId: map['learnerId'] as String,
      classId: map['classId'] as String,
      timeSlot: map['timeSlot'] as String,
      status: map['status'] as String,
      attendance: map['attendance'] as String?,
      attendanceDate: map['attendanceDate'] as int?,
    );
  }
}
