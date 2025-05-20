import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:school_app/services/database_service.dart';
import 'package:school_app/models.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('DatabaseService Validation Tests', () {
    DatabaseService dbService;
    Database db;

    setUp(() async {
      db = await openDatabase(inMemoryDatabasePath);
      dbService = DatabaseService();
      dbService._db = db;
      await Teacher.createTable(db);
      await Learner.createTable(db);
      await Class.createTable(db);
      await Timetable.createTable(db);
      await LearnerTimetable.createTable(db);

      // Seed data
      await db.insert(
          'classes',
          Class(
                  id: 'class_1',
                  teacherId: 'teacher_1',
                  subject: 'Math',
                  grade: '10')
              .toMap());
      await db.insert(
          'classes',
          Class(
                  id: 'class_2',
                  teacherId: 'teacher_1',
                  subject: 'Science',
                  grade: '10')
              .toMap());
      await db.insert('learners',
          Learner(id: 'learner_1', name: 'Alice', grade: '10').toMap());
      await db.insert('learners',
          Learner(id: 'learner_2', name: 'Bob', grade: '10').toMap());
    });

    tearDown(() async {
      await db.close();
    });

    test('Validate timetable - max hours exceeded', () async {
      // Add 6 hours of classes
      await dbService.insertTimetable(Timetable(
        id: 't1',
        classId: 'class_1',
        timeSlot: '2025-05-21 09:00-12:00', // 3 hours
        learnerIds: ['learner_1'],
      ));
      await dbService.insertTimetable(Timetable(
        id: 't2',
        classId: 'class_1',
        timeSlot: '2025-05-21 13:00-16:00', // 3 hours
        learnerIds: ['learner_1'],
      ));

      // Try adding another 1-hour slot
      final timetable = Timetable(
        id: 't3',
        classId: 'class_1',
        timeSlot: '2025-05-21 16:00-17:00',
        learnerIds: ['learner_1'],
      );
      final result = await dbService.validateTimetable(timetable);
      expect(result, contains('Total class hours exceed 6-hour daily limit'));
    });

    test('Validate timetable - learner schedule conflict', () async {
      await dbService.insertTimetable(Timetable(
        id: 't1',
        classId: 'class_1',
        timeSlot: '2025-05-21 09:00-10:00',
        learnerIds: ['learner_1'],
      ));

      final timetable = Timetable(
        id: 't2',
        classId: 'class_2',
        timeSlot: '2025-05-21 09:30-10:30',
        learnerIds: ['learner_1'],
      );
      final result = await dbService.validateTimetable(timetable);
      expect(result, contains('Learner learner_1 has a conflicting schedule'));
    });

    test('Validate timetable - valid with multiple learners', () async {
      final timetable = Timetable(
        id: 't1',
        classId: 'class_1',
        timeSlot: '2025-05-21 09:00-10:00',
        learnerIds: ['learner_1', 'learner_2'],
      );
      final result = await dbService.validateTimetable(timetable);
      expect(result, isNull);
    });
  });
}
