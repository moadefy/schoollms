import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:schoollms/models/teacher.dart';
import 'package:schoollms/models/learner.dart';
import 'package:schoollms/models/class.dart';
import 'package:schoollms/models/timetable.dart';
import 'package:schoollms/models/learnertimetable.dart';
import 'package:schoollms/models/question.dart';
import 'package:schoollms/models/answer.dart';

class DatabaseService {
  late Database _db;
  final _uuid = Uuid();

  Future<void> init() async {
    _db = await openDatabase('school_app.db', version: 1,
        onCreate: (db, version) async {
      await Teacher.createTable(db);
      await Learner.createTable(db);
      await Class.createTable(db);
      await Timetable.createTable(db);
      await LearnerTimetable.createTable(db);
      await Question.createTable(db);
      await Answer.createTable(db);
      await db.execute('''
        CREATE TABLE sync_pending (
          id TEXT PRIMARY KEY,
          table_name TEXT,
          operation TEXT,
          data TEXT,
          modified_at INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE learner_devices (
          learnerId TEXT PRIMARY KEY,
          deviceId TEXT,
          psk TEXT,
          last_sync_time INTEGER
        )
      ''');
      await db.execute('''
        CREATE TABLE teacher_devices (
          teacherId TEXT,
          classId TEXT,
          ip TEXT,
          port INTEGER,
          last_discovered INTEGER,
          PRIMARY KEY (teacherId, classId)
        )
      ''');
      await _seedData(db);
    });
    if (_db == null) {
      _db = await openDatabase('school_app.db');
      await _seedData(_db);
    }
  }

  Future<void> _seedData(Database db) async {
    final teachersCount = await db.query('teachers');
    if (teachersCount.isEmpty) {
      await db.insert(
          'teachers', Teacher(id: 'teacher_1', name: 'Ms. Smith').toMap());
      await db.insert(
          'teachers', Teacher(id: 'teacher_2', name: 'Mr. Jones').toMap());

      await db.insert('learners',
          Learner(id: 'learner_1', name: 'Alice', grade: '10').toMap());
      await db.insert('learners',
          Learner(id: 'learner_2', name: 'Bob', grade: '10').toMap());
      await db.insert('learners',
          Learner(id: 'learner_3', name: 'Charlie', grade: '11').toMap());
      await db.insert('learners',
          Learner(id: 'learner_4', name: 'David', grade: '11').toMap());
      await db.insert('learners',
          Learner(id: 'learner_5', name: 'Eve', grade: '10').toMap());

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
      await db.insert(
          'classes',
          Class(
                  id: 'class_3',
                  teacherId: 'teacher_2',
                  subject: 'English',
                  grade: '11')
              .toMap());

      await _registerLearnerDevice(
          db, 'learner_1', 'device_1', 'teacher_1', 'class_1');
      await _registerLearnerDevice(
          db, 'learner_2', 'device_2', 'teacher_1', 'class_1');
      await _registerLearnerDevice(
          db, 'learner_3', 'device_3', 'teacher_2', 'class_3');
    }
  }

  Future<void> _registerLearnerDevice(Database db, String learnerId,
      String deviceId, String teacherId, String classId) async {
    final psk = _generatePSK(learnerId, teacherId, classId);
    await db.insert(
        'learner_devices',
        {
          'learnerId': learnerId,
          'deviceId': deviceId,
          'psk': psk,
          'last_sync_time': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  String _generatePSK(String learnerId, String teacherId, String classId) {
    final input = '$learnerId:$teacherId:$classId';
    return sha256.convert(utf8.encode(input)).toString().substring(0, 32);
  }

  Future<Map<String, dynamic>> getLearnerDevice(String learnerId) async {
    final maps = await _db.query('learner_devices',
        where: 'learnerId = ?', whereArgs: [learnerId]);
    if (maps.isEmpty) return {};
    return {
      'deviceId': maps[0]['deviceId'],
      'psk': maps[0]['psk'],
      'last_sync_time': maps[0]['last_sync_time'],
    };
  }

  Future<void> updateLastSyncTime(String learnerId, int timestamp) async {
    await _db.update(
      'learner_devices',
      {'last_sync_time': timestamp},
      where: 'learnerId = ?',
      whereArgs: [learnerId],
    );
  }

  Future<void> cacheTeacherDevice(
      String teacherId, String classId, String ip, int port) async {
    await _db.insert(
      'teacher_devices',
      {
        'teacherId': teacherId,
        'classId': classId,
        'ip': ip,
        'port': port,
        'last_discovered': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>> getTeacherDevice(
      String teacherId, String classId) async {
    final maps = await _db.query(
      'teacher_devices',
      where: 'teacherId = ? AND classId = ?',
      whereArgs: [teacherId, classId],
    );
    if (maps.isEmpty) return {};
    return {
      'ip': maps[0]['ip'],
      'port': maps[0]['port'],
      'last_discovered': maps[0]['last_discovered'],
    };
  }

  Future<String?> validateTimetable(Timetable timetable) async {
    try {
      final timeParts = timetable.timeSlot.split(' ');
      if (timeParts.length != 2) return 'Invalid time slot format';
      final date = timeParts[0];
      final times = timeParts[1].split('-');
      if (times.length != 2) return 'Invalid time range';
      final startTime = times[0];
      final endTime = times[1];

      final startHour = int.parse(startTime.split(':')[0]);
      final endHour = int.parse(endTime.split(':')[0]);
      final startMinute = int.parse(startTime.split(':')[1]);
      final endMinute = int.parse(endTime.split(':')[1]);
      if (startHour > endHour ||
          (startHour == endHour && startMinute >= endMinute)) {
        return 'Start time must be before end time';
      }

      final startMinutes = startHour * 60 + startMinute;
      final endMinutes = endHour * 60 + endMinute;
      final newDuration = endMinutes - startMinutes;

      final existing = await _db.query('timetables',
          where: 'classId = ? AND timeSlot LIKE ?',
          whereArgs: [timetable.classId, '$date%']);
      int totalDuration = newDuration;
      for (var map in existing) {
        final existingSlot = map['timeSlot'] as String;
        final existingTimes = existingSlot.split(' ')[1].split('-');
        final existingStart = existingTimes[0];
        final existingEnd = existingTimes[1];
        final exStartHour = int.parse(existingStart.split(':')[0]);
        final exStartMinute = int.parse(existingStart.split(':')[1]);
        final exEndHour = int.parse(existingEnd.split(':')[0]);
        final exEndMinute = int.parse(existingEnd.split(':')[1]);
        final exStartMinutes = exStartHour * 60 + exStartMinute;
        final exEndMinutes = exEndHour * 60 + exEndMinute;

        if (!(endMinutes <= exStartMinutes || startMinutes >= exEndMinutes)) {
          return 'Time slot overlaps with existing schedule';
        }

        totalDuration += exEndMinutes - exStartMinutes;
      }

      if (totalDuration > 360) {
        return 'Total class hours exceed 6-hour daily limit';
      }

      final classData = await _db
          .query('classes', where: 'id = ?', whereArgs: [timetable.classId]);
      if (classData.isEmpty) return 'Invalid class ID';
      final classGrade = classData[0]['grade'] as String;
      for (var learnerId in timetable.learnerIds) {
        final learnerData = await _db
            .query('learners', where: 'id = ?', whereArgs: [learnerId]);
        if (learnerData.isEmpty || learnerData[0]['grade'] != classGrade) {
          return 'Learner $learnerId does not match class grade $classGrade';
        }
      }

      for (var learnerId in timetable.learnerIds) {
        final learnerTimetables = await _db.query('learner_timetables',
            where: 'learnerId = ? AND timeSlot LIKE ?',
            whereArgs: [learnerId, '$date%']);
        for (var lt in learnerTimetables) {
          final ltSlot = lt['timeSlot'] as String;
          final ltTimes = ltSlot.split(' ')[1].split('-');
          final ltStart = ltTimes[0];
          final ltEnd = ltTimes[1];
          final ltStartHour = int.parse(ltStart.split(':')[0]);
          final ltStartMinute = int.parse(ltStart.split(':')[1]);
          final ltEndHour = int.parse(ltEnd.split(':')[0]);
          final ltEndMinute = int.parse(ltEnd.split(':')[1]);
          final ltStartMinutes = ltStartHour * 60 + ltStartMinute;
          final ltEndMinutes = ltEndHour * 60 + ltEndMinute;
          if (!(endMinutes <= ltStartMinutes || startMinutes >= ltEndMinutes)) {
            return 'Learner $learnerId has a conflicting schedule at $ltSlot';
          }
        }
      }

      return null;
    } catch (e) {
      return 'Validation error: $e';
    }
  }

  Future<void> insertTeacher(Teacher teacher) async {
    try {
      await _db.insert('teachers', teacher.toMap());
      await _queueSync('teachers', 'insert', teacher.toMap());
    } catch (e) {
      throw Exception('Failed to insert teacher: $e');
    }
  }

  Future<void> insertLearner(Learner learner) async {
    try {
      await _db.insert('learners', learner.toMap());
      await _queueSync('learners', 'insert', learner.toMap());
    } catch (e) {
      throw Exception('Failed to insert learner: $e');
    }
  }

  Future<List<Learner>> getLearnersByGrade(String grade) async {
    try {
      final maps =
          await _db.query('learners', where: 'grade = ?', whereArgs: [grade]);
      return maps
          .map((map) => Learner(
              id: map['id'] as String,
              name: map['name'] as String,
              grade: map['grade'] as String))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch learners: $e');
    }
  }

  Future<void> insertClass(Class cls) async {
    try {
      await _db.insert('classes', cls.toMap());
      await _queueSync('classes', 'insert', cls.toMap());
    } catch (e) {
      throw Exception('Failed to insert class: $e');
    }
  }

  Future<void> insertTimetable(Timetable timetable) async {
    try {
      final validationError = await validateTimetable(timetable);
      if (validationError != null) throw Exception(validationError);
      await _db.insert('timetables', timetable.toMap());
      await _queueSync('timetables', 'insert', timetable.toMap());
      await _generateLearnerTimetables(timetable);
      final classData = await _db
          .query('classes', where: 'id = ?', whereArgs: [timetable.classId]);
      if (classData.isNotEmpty) {
        final teacherId = classData[0]['teacherId'] as String;
        for (var learnerId in timetable.learnerIds) {
          await _registerLearnerDevice(_db, learnerId, 'device_$learnerId',
              teacherId, timetable.classId);
        }
      }
    } catch (e) {
      throw Exception('Failed to insert timetable: $e');
    }
  }

  Future<List<Timetable>> getTimetables(String classId) async {
    try {
      final maps = await _db
          .query('timetables', where: 'classId = ?', whereArgs: [classId]);
      return maps
          .map((map) => Timetable(
                id: map['id'] as int,
                teacherId: map['teacherId'] as String,
                classId: map['classId'] as String,
                timeSlot: map['timeSlot'] as String,
                learnerIds: (map['learnerIds'] as String).split(','),
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch timetables: $e');
    }
  }

  Future<void> _generateLearnerTimetables(Timetable timetable) async {
    try {
      for (var learnerId in timetable.learnerIds) {
        final learnerTimetable = LearnerTimetable(
          id: _uuid.v4(),
          learnerId: learnerId,
          classId: timetable.classId,
          timeSlot: timetable.timeSlot,
        );
        await _db.insert('learner_timetables', learnerTimetable.toMap());
        await _queueSync(
            'learner_timetables', 'insert', learnerTimetable.toMap());
      }
    } catch (e) {
      throw Exception('Failed to generate learner timetables: $e');
    }
  }

  Future<List<LearnerTimetable>> getLearnerTimetable(String learnerId,
      {int sinceTimestamp = 0}) async {
    try {
      final maps = await _db.query('learner_timetables',
          where: 'learnerId = ? AND modified_at > ?',
          whereArgs: [learnerId, sinceTimestamp]);
      return maps
          .map((map) => LearnerTimetable(
                id: map['id'] as String,
                learnerId: map['learnerId'] as String,
                classId: map['classId'] as String,
                timeSlot: map['timeSlot'] as String,
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch learner timetable: $e');
    }
  }

  Future<void> insertQuestion(Question question) async {
    try {
      final timetableData = await _db.query('timetables',
          where: 'id = ?', whereArgs: [question.timetableId]);
      if (timetableData.isEmpty) throw Exception('Invalid timetable ID');
      if (timetableData[0]['classId'] != question.classId)
        throw Exception('Class ID does not match timetable');
      await _db.insert('questions', question.toMap());
      await _queueSync('questions', 'insert', question.toMap());
    } catch (e) {
      throw Exception('Failed to insert question: $e');
    }
  }

  Future<List<Question>> getQuestionsByTimetable(String timetableId) async {
    try {
      final maps = await _db.query('questions',
          where: 'timetableId = ?', whereArgs: [timetableId]);
      return maps
          .map((map) => Question(
                id: map['id'] as String,
                timetableId: map['timetableId'] as String,
                classId: map['classId'] as String,
                content: map['content'] as String,
                pdfPage: map['pdfPage'] as int,
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch questions: $e');
    }
  }

  Future<void> insertAnswer(Answer answer) async {
    try {
      final questionData = await _db
          .query('questions', where: 'id = ?', whereArgs: [answer.questionId]);
      if (questionData.isEmpty) throw Exception('Invalid question ID');
      final timetableId = questionData[0]['timetableId'];
      final timetableData = await _db
          .query('timetables', where: 'id = ?', whereArgs: [timetableId]);
      if (timetableData.isEmpty) throw Exception('Invalid timetable ID');
      final learnerIds = (timetableData[0]['learnerIds'] as String).split(',');
      if (!learnerIds.contains(answer.learnerId))
        throw Exception('Learner not authorized for this question');
      await _db.insert('answers', answer.toMap());
      await _queueSync('answers', 'insert', answer.toMap());
    } catch (e) {
      throw Exception('Failed to insert answer: $e');
    }
  }

  Future<List<Answer>> getAnswersByQuestion(String questionId) async {
    try {
      final maps = await _db
          .query('answers', where: 'questionId = ?', whereArgs: [questionId]);
      return maps
          .map((map) => Answer(
                id: map['id'] as String,
                questionId: map['questionId'] as String,
                learnerId: map['learnerId'] as String,
                content: map['content'] as String,
                submitted_at: map['submitted_at'] as int,
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch answers: $e');
    }
  }

  Future<void> _queueSync(
      String table, String operation, Map<String, dynamic> data) async {
    try {
      await _db.insert('sync_pending', {
        'id': _uuid.v4(),
        'table_name': table,
        'operation': operation,
        'data': jsonEncode(data),
        'modified_at': DateTime.now().millisecondsSinceEpoch,
      });
    } catch (e) {
      throw Exception('Failed to queue sync: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getPendingSyncs(
      {int sinceTimestamp = 0}) async {
    try {
      final maps = await _db.query('sync_pending',
          where: 'modified_at > ?', whereArgs: [sinceTimestamp]);
      return maps
          .map((map) => {
                'id': map['id'],
                'table_name': map['table_name'],
                'operation': map['operation'],
                'data': jsonDecode(map['data'] as String),
                'modified_at': map['modified_at'],
              })
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch pending syncs: $e');
    }
  }

  Future<void> clearPendingSync(String id) async {
    try {
      await _db.delete('sync_pending', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Failed to clear pending sync: $e');
    }
  }
}
