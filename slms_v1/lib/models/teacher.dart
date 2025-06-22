import 'package:sqflite/sqflite.dart';

class Teacher {
  final String id;
  final String name;
  String? timetableId; // Links to a Timetable, which contains TimetableSlots

  Teacher({
    required this.id,
    required this.name,
    this.timetableId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'timetableId': timetableId,
    };
  }

  factory Teacher.fromMap(Map<String, dynamic> map) {
    return Teacher(
      id: map['id'] as String,
      name: map['name'] as String,
      timetableId: map['timetableId'] as String?,
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE teachers (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        timetableId TEXT,
        FOREIGN KEY (timetableId) REFERENCES timetables(id) ON DELETE SET NULL
      )
    ''');
  }

  // Optional: Method to fetch associated TimetableSlots (to be implemented in service)
  // This will be handled in DatabaseService later
}
