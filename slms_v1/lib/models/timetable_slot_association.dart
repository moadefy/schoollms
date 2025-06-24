import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class TimetableSlotAssociation {
  final String id;
  final String userId;
  final String timetableId;
  final String slotId;

  TimetableSlotAssociation({
    required this.id,
    required this.userId,
    required this.timetableId,
    required this.slotId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'timetableId': timetableId,
      'slotId': slotId,
    };
  }

  factory TimetableSlotAssociation.fromMap(Map<String, dynamic> map) {
    return TimetableSlotAssociation(
      id: map['id'] as String,
      userId: map['userId'] as String,
      timetableId: map['timetableId'] as String,
      slotId: map['slotId'] as String,
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE timetable_slot_association (
        id TEXT PRIMARY KEY,
        userId TEXT NOT NULL,
        timetableId TEXT NOT NULL,
        slotId TEXT NOT NULL,
        FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (timetableId) REFERENCES timetables(id) ON DELETE CASCADE,
        FOREIGN KEY (slotId) REFERENCES timetable_slots(id) ON DELETE CASCADE,
        UNIQUE (userId, slotId) -- Ensure no duplicate associations
      )
    ''');
  }
}
