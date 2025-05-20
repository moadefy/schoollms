class Class {
  final String id;
  final String teacherId;
  final String subject;
  final String grade;

  Class({this.id, this.teacherId, this.subject, this.grade});

  Map<String, dynamic> toMap() => {
        'id': id,
        'teacherId': teacherId,
        'subject': subject,
        'grade': grade,
      };

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE classes (
        id TEXT PRIMARY KEY,
        teacherId TEXT,
        subject TEXT,
        grade TEXT
      )
    ''');
  }
}
