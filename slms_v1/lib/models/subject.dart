import 'package:sqflite/sqflite.dart';

class Subject {
  final String id;
  final String name;
  final List<String> gradeIds; // List of associated grade IDs

  Subject({
    required this.id,
    required this.name,
    this.gradeIds = const [], // Default to empty list if not specified
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'gradeIds': gradeIds.join(
          ','), // Convert List<String> to comma-separated string for storage
    };
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE subjects (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        gradeIds TEXT
      )
    ''');
  }

  // Factory method to create Subject from map (e.g., from database query)
  factory Subject.fromMap(Map<String, dynamic> map) {
    return Subject(
      id: map['id'] as String,
      name: map['name'] as String,
      gradeIds: (map['gradeIds'] as String?)?.split(',') ?? [],
    );
  }
}
