import 'package:sqflite/sqflite.dart';

class Timetable {
  final String id;
  final String teacherId;
  final String? userId;
  final String? userRole;

  Timetable({
    required this.id,
    required this.teacherId,
    this.userId,
    this.userRole,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'userId': userId,
      'userRole': userRole,
    };
  }

  factory Timetable.fromMap(Map<String, dynamic> map) {
    return Timetable(
      id: map['id'] as String,
      teacherId: map['teacherId'] as String,
      userId: map['userId'] as String?,
      userRole: map['userRole'] as String?,
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE timetables (
        id TEXT PRIMARY KEY,
        teacherId TEXT,
        userId TEXT,
        userRole TEXT,
        FOREIGN KEY (teacherId) REFERENCES teachers(id) ON DELETE SET NULL
      )
    ''');
  }
}
