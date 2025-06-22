import 'package:sqflite/sqflite.dart';

class LearnerTimetable {
  final String id;
  final String learnerId;
  final String classId;
  final String timeSlot;
  String status;
  String? attendance;
  int? attendanceDate;

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
      'id': id,
      'learnerId': learnerId,
      'classId': classId,
      'timeSlot': timeSlot,
      'status': status,
      'attendance': attendance,
      'attendanceDate': attendanceDate,
    };
  }

  factory LearnerTimetable.fromMap(Map<String, dynamic> map) {
    return LearnerTimetable(
      id: map['id'] as String,
      learnerId: map['learnerId'] as String,
      classId: map['classId'] as String,
      timeSlot: map['timeSlot'] as String,
      status: map['status'] as String,
      attendance: map['attendance'] as String?,
      attendanceDate: map['attendanceDate'] as int?,
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE learner_timetables (
        id TEXT PRIMARY KEY,
        learnerId TEXT NOT NULL,
        classId TEXT NOT NULL,
        timeSlot TEXT NOT NULL,
        status TEXT NOT NULL,
        attendance TEXT,
        attendanceDate INTEGER,
        modified_at INTEGER DEFAULT 0,
        FOREIGN KEY (learnerId) REFERENCES learners(id) ON DELETE CASCADE,
        FOREIGN KEY (classId) REFERENCES classes(id) ON DELETE CASCADE
      )
    ''');
  }
}
