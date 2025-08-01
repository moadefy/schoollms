import 'package:sqflite/sqflite.dart';

class Class {
  final String id;
  final String teacherId;
  final String subject;
  final String grade;

  Class({
    required this.id,
    required this.teacherId,
    required this.subject,
    required this.grade,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'subject': subject,
      'grade': grade,
    };
  }

  factory Class.fromMap(Map<String, dynamic> map) {
    return Class(
      id: map['id'] as String,
      teacherId: map['teacherId'] as String,
      subject: map['subject'] as String,
      grade: map['grade'] as String,
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE classes (
        id TEXT PRIMARY KEY,
        teacherId TEXT NOT NULL,
        subject TEXT NOT NULL,
        grade TEXT NOT NULL,
        FOREIGN KEY (teacherId) REFERENCES teachers(id) ON DELETE CASCADE
      )
    ''');
  }
}
