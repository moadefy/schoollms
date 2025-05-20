class LearnerTimetable {
  final String id;
  final String learnerId;
  final String classId;
  final String timeSlot;

  LearnerTimetable({this.id, this.learnerId, this.classId, this.timeSlot});

  Map<String, dynamic> toMap() => {
        'id': id,
        'learnerId': learnerId,
        'classId': classId,
        'timeSlot': timeSlot,
      };

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE learner_timetables (
        id TEXT PRIMARY KEY,
        learnerId TEXT,
        classId TEXT,
        timeSlot TEXT
      )
    ''');
  }
}