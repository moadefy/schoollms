class Teacher {
  final String id;
  final String name;

  Teacher({this.id, this.name});

  Map<String, dynamic> toMap() => {'id': id, 'name': name};

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE teachers (
        id TEXT PRIMARY KEY,
        name TEXT
      )
    ''');
  }
}
