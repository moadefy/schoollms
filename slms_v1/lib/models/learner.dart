class Learner {
  final String id;
  final String name;
  final String grade;

  Learner({this.id, this.name, this.grade});

  Map<String, dynamic> toMap() => {'id': id, 'name': name, 'grade': grade};

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
