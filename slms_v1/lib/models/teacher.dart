import 'package:sqflite/sqflite.dart'; // Added import for Database

class Teacher {
  final String id;
  final String name;
  final String? email; // Optional field
  final String? phone; // Optional field

  Teacher({
    required this.id,
    required this.name,
    this.email,
    this.phone,
  });

  // Factory constructor to create Teacher from a map (e.g., database result)
  factory Teacher.fromMap(Map<String, dynamic> map) {
    return Teacher(
      id: map['id'] as String,
      name: map['name'] as String,
      email: map['email'] as String?,
      phone: map['phone'] as String?,
    );
  }

  // Convert Teacher to a map for database storage
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
    };
  }

  // Create the teachers table in the database
  static Future<void> createTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE teachers (
          id TEXT PRIMARY KEY,
          name TEXT NOT NULL,
          email TEXT,
          phone TEXT
        )
      ''');
    } catch (e) {
      throw Exception('Failed to create teachers table: $e');
    }
  }
}
