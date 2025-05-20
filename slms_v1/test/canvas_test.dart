import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:schoollms/services/database_service.dart';
import 'package:schoollms/models/timetable.dart' hide DatabaseService;
import 'package:schoollms/models/question.dart';
import 'package:schoollms/models/answer.dart';
import 'package:schoollms/models/learner.dart';
import 'package:schoollms/models/teacher.dart';



void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Canvas Tests', () {
    DatabaseService dbService;
    Database db;

    setUp() async {
      db = await openDatabase(inMemoryDatabasePath);
      dbService = DatabaseService().._db = db;
      await dbService.init();
    });

    tearDown() async {
      await db.close();
    });

    test('Insert and retrieve question', () async {
      final timetable = Timetable(
        id: 't1',
        classId: 'class_1',
        timeSlot: '2025-05-21 09:00-10:00',
        learnerIds: ['learner_1'],
      );
      await dbService.insertTimetable(timetable);

      final question = Question(
        id: 'q1',
        timetableId: 't1',
        classId: 'class_1',
        type: 'multiple-choice',
        content: 'What is 2+2?',
        options: ['2', '3', '4', '5'],
      );
      await dbService.insertQuestion(question);

      final questions = await dbService.getQuestionsByTimetable('t1');
      expect(questions.length, 1);
      expect(questions[0].content, 'What is 2+2?');
      expect(questions[0].options, ['2', '3', '4', '5']);
    });

    test('Insert answer with valid learner', () async {
      final timetable = Timetable(
        id: 't1',
        classId: 'class_1',
        timeSlot: '2025-05-21 09:00-10:00',
        learnerIds: ['learner_1'],
      );
      await dbService.insertTimetable(timetable);

      final question = Question(
        id: 'q1',
        timetableId: 't1',
        classId: 'class_1',
        type: 'open-ended',
        content: 'Explain gravity',
      );
      await dbService.insertQuestion(question);

      final answer = Answer(
        id: 'a1',
        questionId: 'q1',
        learnerId: 'learner_1',
        content: 'Gravity is a force...',
        submitted_at: DateTime.now().millisecondsSinceEpoch,
      );
      await dbService.insertAnswer(answer);

      final answers = await dbService.getAnswersByQuestion('q1');
      expect(answers.length, 1);
      expect(answers[0].content, 'Gravity is a force...');
    });

    test('Reject answer from unauthorized learner', () async {
      final timetable = Timetable(
        id: 't1',
        classId: 'class_1',
        timeSlot: '2025-05-21 09:00-10:00',
        learnerIds: ['learner_1'],
      );
      await dbService.insertTimetable(timetable);

      final question = Question(
        id: 'q1',
        timetableId: 't1',
        classId: 'class_1',
        type: 'open-ended',
        content: 'Explain gravity',
      );
      await dbService.insertQuestion(question);

      final answer = Answer(
        id: 'a1',
        questionId: 'q1',
        learnerId: 'learner_2',
        content: 'Gravity is a force...',
        submitted_at: DateTime.now().millisecondsSinceEpoch,
      );
      expect(() async => await dbService.insertAnswer(answer), throwsException);
    });
  });
}