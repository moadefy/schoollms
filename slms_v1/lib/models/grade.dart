import 'package:sqflite/sqflite.dart';

class Grade {
  final String id;
  final String number; // Changed from int to String to accommodate 'R'

  Grade({required this.id, required this.number});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'number': number,
    };
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE grades (
        id TEXT PRIMARY KEY,
        number TEXT NOT NULL
      )
    ''');
  }
}
