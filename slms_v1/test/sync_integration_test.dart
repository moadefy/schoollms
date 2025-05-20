import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:school_app/services/database_service.dart';
import 'package:school_app/services/sync_service.dart';
import 'package:school_app/models.dart';
import 'package:mockito/mockito.dart';

class MockWiFiIoT extends Mock implements WiFiForIoTPlugin {}

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Sync Integration Tests', () {
    DatabaseService teacherDbService;
    DatabaseService learnerDbService;
    SyncService teacherSyncService;
    SyncService learnerSyncService;
    Database teacherDb;
    Database learnerDb;

    setUp() async {
      teacherDb = await openDatabase(inMemoryDatabasePath);
      learnerDb = await openDatabase(inMemoryDatabasePath);
      teacherDbService = DatabaseService().._db = teacherDb;
      learnerDbService = DatabaseService().._db = learnerDb;
      teacherSyncService = SyncService(teacherDbService);
      learnerSyncService = SyncService(learnerDbService);

      await teacherDbService.init();
      await learnerDbService.init();
    }

    tearDown() async {
      await teacherDb.close();
      await learnerDb.close();
    });

    test('Delta sync and batching', () async {
      // Seed teacher data
      await teacherDbService.insertClass(Class(id: 'class_1', teacherId: 'teacher_1', subject: 'Math', grade: '10'));
      await teacherDbService.insertLearner(Learner(id: 'learner_1', name: 'Alice', grade: '10'));
      await teacherDbService.insertTimetable(Timetable(
        id: 't1',
        classId: 'class_1',
        timeSlot: '2025-05-21 09:00-10:00',
        learnerIds: ['learner_1'],
      ));

      // Start sync server
      await teacherSyncService.startSyncServer('teacher_1', 'class_1');

      // Simulate learner sync
      await learnerSyncService.connectLearner('teacher_1', 'class_1', 'learner_1');

      // Verify learner received timetable
      final learnerTimetables = await learnerDbService.getLearnerTimetable('learner_1');
      expect(learnerTimetables.length, 1);
      expect(learnerTimetables[0].timeSlot, '2025-05-21 09:00-10:00');

      // Add more timetables and test delta sync
      await teacherDbService.insertTimetable(Timetable(
        id: 't2',
        classId: 'class_1',
        timeSlot: '2025-05-21 10:00-11:00',
        learnerIds: ['learner_1'],
      ));

      await learnerSyncService.connectLearner('teacher_1', 'class_1', 'learner_1');
      final updatedTimetables = await learnerDbService.getLearnerTimetable('learner_1');
      expect(updatedTimetables.length, 2);
    });
  });
}