import 'package:sqflite/sqflite.dart';

class Language {
  final String id;
  final String name;

  Language({required this.id, required this.name});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
    };
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE languages (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL
      )
    ''');
  }
}
