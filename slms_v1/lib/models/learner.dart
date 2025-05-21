import 'package:sqflite/sqflite.dart';

class Learner {
  final String id;
  final String name;
  final String grade;

  Learner({
    required this.id,
    required this.name,
    required this.grade,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'grade': grade,
      };

  static Learner fromMap(Map<String, dynamic> map) {
    return Learner(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      grade: map['grade'] as String? ?? '',
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE learners (
        id TEXT PRIMARY KEY,
        name TEXT,
        grade TEXT
      )
    ''');
  }
}
