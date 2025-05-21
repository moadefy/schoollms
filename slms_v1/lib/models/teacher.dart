import 'package:sqflite/sqflite.dart';

class Teacher {
  final String id;
  final String name;

  Teacher({
    required this.id,
    required this.name,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
      };

  static Teacher fromMap(Map<String, dynamic> map) {
    return Teacher(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE teachers (
        id TEXT PRIMARY KEY,
        name TEXT
      )
    ''');
  }
}
