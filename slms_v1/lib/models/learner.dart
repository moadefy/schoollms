import 'package:sqflite/sqflite.dart'; // Added import for Database

class Learner {
  final String id;
  final String name;
  final String grade;

  Learner({
    required this.id,
    required this.name,
    required this.grade,
  });

  // Factory constructor to create Learner from a map (e.g., database result)
  factory Learner.fromMap(Map<String, dynamic> map) {
    return Learner(
      id: map['id'] as String,
      name: map['name'] as String,
      grade: map['grade'] as String,
    );
  }

  // Convert Learner to a map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'grade': grade,
    };
  }

  // Create the learners table in the database
  static Future<void> createTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE learners (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          grade TEXT NOT NULL
        )
      ''');
    } catch (e) {
      throw Exception('Failed to create learners table: $e');
    }
  }
}
