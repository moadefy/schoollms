import 'package:sqflite/sqflite.dart';

class Timetable {
  final String id; // Changed from int to String for UUID
  final String teacherId;
  final String classId;
  String timeSlot; // Non-final to allow updates during drag-and-drop
  List<String> learnerIds; // Non-final to allow updates

  Timetable({
    required this.id,
    required this.teacherId,
    required this.classId,
    required this.timeSlot,
    required this.learnerIds,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id, // Store as string
      'teacherId': teacherId,
      'classId': classId,
      'timeSlot': timeSlot,
      'learnerIds':
          learnerIds.join(','), // Convert list to comma-separated string
    };
  }

  factory Timetable.fromMap(Map<String, dynamic> map) {
    return Timetable(
      id: map['id'] as String, // Cast id as String
      teacherId: map['teacherId'] as String,
      classId: map['classId'] as String,
      timeSlot: map['timeSlot'] as String,
      learnerIds: (map['learnerIds'] as String)
          .split(','), // Convert string back to list
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE timetables (
        id TEXT PRIMARY KEY, -- Changed to TEXT PRIMARY KEY for UUID
        teacherId TEXT NOT NULL,
        classId TEXT NOT NULL,
        timeSlot TEXT NOT NULL,
        learnerIds TEXT NOT NULL,
        FOREIGN KEY (teacherId) REFERENCES teachers(id) ON DELETE CASCADE,
        FOREIGN KEY (classId) REFERENCES classes(id) ON DELETE CASCADE
      )
    ''');
  }
}
