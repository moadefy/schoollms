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
import 'package:schoollms/models/assessment.dart';
import 'package:schoollms/models/asset.dart';
import 'package:schoollms/models/analytics.dart';
import 'package:schoollms/widgets/canvas_widget.dart';

class DatabaseService {
  Database? _db;
  final _uuid = const Uuid(); // Changed to const for performance

  Future<void> init() async {
    print("Starting database initialization");
    _db = await openDatabase(
      'schoollms.db',
      version: 2, // Increment version to trigger migration if needed
      onCreate: (db, version) async {
        print("Creating tables");
        await _createTables(db);
        print("Seeding data");
        await _seedData(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print("Upgrading database from $oldVersion to $newVersion");
        if (oldVersion < 2) {
          try {
            print("Applying schema updates for version 2");
            // No migration needed for fresh install, but prepare for future
            await _createTables(db); // Recreate tables to ensure consistency
            print("Schema updated successfully");
          } catch (e) {
            print("Upgrade error: $e");
            rethrow; // Let the app crash with details for debugging
          }
        }
      },
    );
    print("Database initialized");
  }

  Future<void> _createTables(Database db) async {
    print("Creating Teacher table");
    await Teacher.createTable(db);
    print("Creating Learner table");
    await Learner.createTable(db);
    print("Creating Class table");
    await Class.createTable(db);
    print("Creating Timetable table");
    await Timetable.createTable(db);
    print("Creating LearnerTimetable table");
    await LearnerTimetable.createTable(db);
    print("Creating Question table");
    await Question.createTable(db);
    print("Creating Answer table");
    await Answer.createTable(db);
    print("Creating Assessment table");
    await Assessment.createTable(db);
    print("Creating Assets table");
    await db.execute('''
      CREATE TABLE assets (
        id TEXT PRIMARY KEY,
        learnerId TEXT,
        questionId TEXT,
        type TEXT, -- e.g., 'image' or 'pdf'
        data TEXT, -- Base64-encoded data or path
        positionX REAL,
        positionY REAL,
        scale REAL,
        created_at INTEGER
      )
    ''');
    print("Creating Analytics table");
    await db.execute('''
      CREATE TABLE analytics (
        id TEXT PRIMARY KEY,
        questionId TEXT,
        learnerId TEXT,
        timeSpentSeconds INTEGER,
        submissionStatus TEXT,
        deviceId TEXT,
        timestamp INTEGER
      )
    ''');
    print("Creating SyncPending table");
    await db.execute('''
      CREATE TABLE sync_pending (
        id TEXT PRIMARY KEY,
        table_name TEXT,
        operation TEXT,
        data TEXT,
        modified_at INTEGER
      )
    ''');
    print("Creating LearnerDevices table");
    await db.execute('''
      CREATE TABLE learner_devices (
        learnerId TEXT PRIMARY KEY,
        deviceId TEXT,
        psk TEXT,
        last_sync_time INTEGER
      )
    ''');
    print("Creating TeacherDevices table");
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
  }

  Future<void> _seedData(Database db) async {
    final teachersCount = Sqflite.firstIntValue(
        await db.query('teachers', columns: ['COUNT(*)']));
    if (teachersCount == 0) {
      print("Seeding Teachers");
      await db.insert(
          'teachers', Teacher(id: 'teacher_1', name: 'Ms. Smith').toMap());
      await db.insert(
          'teachers', Teacher(id: 'teacher_2', name: 'Mr. Jones').toMap());

      print("Seeding Learners");
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

      print("Seeding Classes");
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

      print("Registering Learner Devices");
      await _registerLearnerDevice(
          db, 'learner_1', 'device_1', 'teacher_1', 'class_1');
      await _registerLearnerDevice(
          db, 'learner_2', 'device_2', 'teacher_1', 'class_1');
      await _registerLearnerDevice(
          db, 'learner_3', 'device_3', 'teacher_2', 'class_3');
    }
  }

  Future<void> _registerLearnerDevice(DatabaseExecutor db, String learnerId,
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
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  String _generatePSK(String learnerId, String teacherId, String classId) {
    final input =
        '$learnerId:$teacherId:$classId:${DateTime.now().millisecondsSinceEpoch}';
    return sha256.convert(utf8.encode(input)).toString().substring(0, 32);
  }

  Future<Map<String, dynamic>> getLearnerDevice(String learnerId) async {
    final maps = await _db!.query('learner_devices',
        where: 'learnerId = ?', whereArgs: [learnerId]);
    return maps.isNotEmpty
        ? {
            'deviceId': maps[0]['deviceId'],
            'psk': maps[0]['psk'],
            'last_sync_time': maps[0]['last_sync_time'],
          }
        : {};
  }

  Future<void> updateLastSyncTime(String learnerId, int timestamp) async {
    await _db!.update(
      'learner_devices',
      {'last_sync_time': timestamp},
      where: 'learnerId = ?',
      whereArgs: [learnerId],
    );
  }

  Future<void> cacheTeacherDevice(
      String teacherId, String classId, String ip, int port) async {
    await _db!.insert(
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
    final maps = await _db!.query(
      'teacher_devices',
      where: 'teacherId = ? AND classId = ?',
      whereArgs: [teacherId, classId],
    );
    return maps.isNotEmpty
        ? {
            'ip': maps[0]['ip'],
            'port': maps[0]['port'],
            'last_discovered': maps[0]['last_discovered'],
          }
        : {};
  }

  Future<String?> validateTimetable(Timetable timetable) async {
    try {
      final timeParts = timetable.timeSlot.split(' ');
      if (timeParts.length != 2)
        return 'Invalid time slot format (expected "date time-time")';
      final date = timeParts[0];
      final times = timeParts[1].split('-');
      if (times.length != 2) return 'Invalid time range';
      final startTime = times[0].split(':');
      final endTime = times[1].split(':');
      if (startTime.length != 2 || endTime.length != 2)
        return 'Invalid time format (HH:MM)';

      final startHour = int.parse(startTime[0]);
      final endHour = int.parse(endTime[0]);
      final startMinute = int.parse(startTime[1]);
      final endMinute = int.parse(endTime[1]);
      if (startHour < 0 ||
          startHour > 23 ||
          endHour < 0 ||
          endHour > 23 ||
          startMinute < 0 ||
          startMinute > 59 ||
          endMinute < 0 ||
          endMinute > 59) {
        return 'Invalid hour or minute values';
      }
      if (startHour > endHour ||
          (startHour == endHour && startMinute >= endMinute)) {
        return 'Start time must be before end time';
      }

      final startMinutes = startHour * 60 + startMinute;
      final endMinutes = endHour * 60 + endMinute;
      final newDuration = endMinutes - startMinutes;

      final existing = await _db!.query('timetables',
          where: 'classId = ? AND timeSlot LIKE ?',
          whereArgs: [timetable.classId, '$date%']);
      int totalDuration = newDuration;
      for (final map in existing) {
        final existingSlot = map['timeSlot'] as String;
        final existingTimes = existingSlot.split(' ')[1].split('-');
        final existingStart = existingTimes[0].split(':');
        final existingEnd = existingTimes[1].split(':');
        final exStartHour = int.parse(existingStart[0]);
        final exStartMinute = int.parse(existingStart[1]);
        final exEndHour = int.parse(existingEnd[0]);
        final exEndMinute = int.parse(existingEnd[1]);
        final exStartMinutes = exStartHour * 60 + exStartMinute;
        final exEndMinutes = exEndHour * 60 + exEndMinute;

        if (!(endMinutes <= exStartMinutes || startMinutes >= exEndMinutes)) {
          return 'Time slot overlaps with existing schedule';
        }
        totalDuration += exEndMinutes - exStartMinutes;
      }

      const maxDailyMinutes = 360; // 6 hours
      if (totalDuration > maxDailyMinutes) {
        return 'Total class hours exceed $maxDailyMinutes-minute daily limit';
      }

      final classData = await _db!
          .query('classes', where: 'id = ?', whereArgs: [timetable.classId]);
      if (classData.isEmpty) return 'Invalid class ID';
      final classGrade = classData[0]['grade'] as String;
      for (final learnerId in timetable.learnerIds) {
        final learnerData = await _db!
            .query('learners', where: 'id = ?', whereArgs: [learnerId]);
        if (learnerData.isEmpty || learnerData[0]['grade'] != classGrade) {
          return 'Learner $learnerId does not match class grade $classGrade';
        }
      }

      for (final learnerId in timetable.learnerIds) {
        final learnerTimetables = await _db!.query('learner_timetables',
            where: 'learnerId = ? AND timeSlot LIKE ?',
            whereArgs: [learnerId, '$date%']);
        for (final lt in learnerTimetables) {
          final ltSlot = lt['timeSlot'] as String;
          final ltTimes = ltSlot.split(' ')[1].split('-');
          final ltStart = ltTimes[0].split(':');
          final ltEnd = ltTimes[1].split(':');
          final ltStartHour = int.parse(ltStart[0]);
          final ltStartMinute = int.parse(ltStart[1]);
          final ltEndHour = int.parse(ltEnd[0]);
          final ltEndMinute = int.parse(ltEnd[1]);
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
      await _db!.transaction((txn) async {
        await txn.insert('teachers', teacher.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        await _queueSync(txn, 'teachers', 'insert', teacher.toMap());
      });
    } catch (e) {
      throw Exception('Failed to insert teacher: $e');
    }
  }

  Future<void> insertLearner(Learner learner) async {
    try {
      await _db!.transaction((txn) async {
        await txn.insert('learners', learner.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        await _queueSync(txn, 'learners', 'insert', learner.toMap());
      });
    } catch (e) {
      throw Exception('Failed to insert learner: $e');
    }
  }

  Future<List<Learner>> getLearnersByGrade(String grade) async {
    try {
      final maps =
          await _db!.query('learners', where: 'grade = ?', whereArgs: [grade]);
      return maps
          .map((map) => Learner(
                id: map['id'] as String,
                name: map['name'] as String,
                grade: map['grade'] as String,
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch learners: $e');
    }
  }

  Future<void> insertClass(Class cls) async {
    try {
      await _db!.transaction((txn) async {
        await txn.insert('classes', cls.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        await _queueSync(txn, 'classes', 'insert', cls.toMap());
      });
    } catch (e) {
      throw Exception('Failed to insert class: $e');
    }
  }

  Future<List<Class>> getClassesByTeacher(String teacherId) async {
    try {
      final maps = await _db!
          .query('classes', where: 'teacherId = ?', whereArgs: [teacherId]);
      return maps
          .map((map) => Class(
                id: map['id'] as String,
                teacherId: map['teacherId'] as String,
                subject: map['subject'] as String,
                grade: map['grade'] as String,
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch classes by teacher: $e');
    }
  }

  Future<void> insertTimetable(Timetable timetable) async {
    try {
      final validationError = await validateTimetable(timetable);
      if (validationError != null) throw Exception(validationError);
      await _db!.transaction((txn) async {
        await txn.insert('timetables', timetable.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        await _queueSync(txn, 'timetables', 'insert', timetable.toMap());
        await _generateLearnerTimetables(txn, timetable);
        final classData = await txn
            .query('classes', where: 'id = ?', whereArgs: [timetable.classId]);
        if (classData.isEmpty) {
          throw Exception('Invalid class ID');
        }
        final teacherId = classData[0]['teacherId'] as String;
        for (final learnerId in timetable.learnerIds) {
          await _registerLearnerDevice(txn, learnerId, 'device_$learnerId',
              teacherId, timetable.classId);
        }
      });
    } catch (e) {
      throw Exception('Failed to insert timetable: $e');
    }
  }

  Future<List<Timetable>> getTimetables(String classId) async {
    try {
      final maps = await _db!
          .query('timetables', where: 'classId = ?', whereArgs: [classId]);
      return maps
          .map((map) => Timetable(
                id: map['id'] as String,
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

  Future<void> _generateLearnerTimetables(
      DatabaseExecutor txn, Timetable timetable) async {
    try {
      for (final learnerId in timetable.learnerIds) {
        final learnerTimetable = LearnerTimetable(
          id: _uuid.v4(), // Generate UUID for id
          learnerId: learnerId,
          classId: timetable.classId,
          timeSlot: timetable.timeSlot,
          status: 'active',
        );
        await txn.insert('learner_timetables', learnerTimetable.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        await _queueSync(
            txn, 'learner_timetables', 'insert', learnerTimetable.toMap());
      }
    } catch (e) {
      throw Exception('Failed to generate learner timetables: $e');
    }
  }

  Future<List<LearnerTimetable>> getLearnerTimetable(String learnerId,
      {int sinceTimestamp = 0}) async {
    try {
      final maps = await _db!.query('learner_timetables',
          where: 'learnerId = ? AND modified_at > ?',
          whereArgs: [learnerId, sinceTimestamp]);
      return maps
          .map((map) => LearnerTimetable(
                id: map['id'] as String,
                learnerId: map['learnerId'] as String,
                classId: map['classId'] as String,
                timeSlot: map['timeSlot'] as String,
                status: map['status'] as String,
                attendance: map['attendance'] as String?,
                attendanceDate: map['attendanceDate'] as int?,
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch learner timetable: $e');
    }
  }

  Future<void> insertLearnerTimetable(LearnerTimetable learnerTimetable) async {
    try {
      await _db!.transaction((txn) async {
        await txn.insert('learner_timetables', learnerTimetable.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        await _queueSync(
            txn, 'learner_timetables', 'insert', learnerTimetable.toMap());
      });
    } catch (e) {
      throw Exception('Failed to insert learner timetable: $e');
    }
  }

  Future<void> insertQuestion(Question question) async {
    try {
      await _db!.transaction((txn) async {
        final classData = await txn
            .query('classes', where: 'id = ?', whereArgs: [question.classId]);
        if (classData.isEmpty) throw Exception('Invalid class ID');
        if (question.assessmentId != null) {
          final assessmentData = await txn.query('assessments',
              where: 'id = ?', whereArgs: [question.assessmentId]);
          if (assessmentData.isEmpty) throw Exception('Invalid assessment ID');
          final classIds =
              (jsonDecode(assessmentData[0]['classIds'] as String) as List)
                  .cast<String>();
          if (!classIds.contains(question.classId)) {
            throw Exception('Assessment does not include the specified class');
          }
        }
        await txn.insert('questions', question.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        await _queueSync(txn, 'questions', 'insert', question.toMap());
      });
    } catch (e) {
      throw Exception('Failed to insert question: $e');
    }
  }

  Future<List<Question>> getQuestionsByClass(String classId) async {
    try {
      final maps = await _db!
          .query('questions', where: 'classId = ?', whereArgs: [classId]);
      return maps
          .map((map) => Question(
                id: map['id'] as String,
                timetableId: map['timetableId'] as String?,
                classId: map['classId'] as String,
                assessmentId: map['assessmentId'] as String?,
                content: map['content'] as String,
                pdfPage: map['pdfPage'] as int?,
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch questions: $e');
    }
  }

  Future<void> insertAnswer(Answer answer) async {
    try {
      await _db!.transaction((txn) async {
        final questionData = await txn.query('questions',
            where: 'id = ?', whereArgs: [answer.questionId]);
        if (questionData.isEmpty) throw Exception('Invalid question ID');
        final classId = questionData[0]['classId'] as String;
        final classData =
            await txn.query('classes', where: 'id = ?', whereArgs: [classId]);
        if (classData.isEmpty) throw Exception('Invalid class ID');
        final timetableIds = await txn
            .query('timetables', where: 'classId = ?', whereArgs: [classId]);
        final learnerTimetables = await txn.query('learner_timetables',
            where: 'learnerId = ? AND classId = ?',
            whereArgs: [answer.learnerId, classId]);
        if (learnerTimetables.isEmpty)
          throw Exception('Learner not enrolled in class');
        await txn.insert('answers', answer.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        await _queueSync(txn, 'answers', 'insert', answer.toMap());
      });
    } catch (e) {
      throw Exception('Failed to insert answer: $e');
    }
  }

  Future<List<Answer>> getAnswersByQuestion(String questionId) async {
    try {
      final maps = await _db!
          .query('answers', where: 'questionId = ?', whereArgs: [questionId]);
      return maps
          .map((map) => Answer(
                id: map['id'] as String,
                questionId: map['questionId'] as String,
                learnerId: map['learnerId'] as String,
                strokes: (jsonDecode(map['strokes'] as String) as List)
                    .map((s) => Stroke.fromJson(s).toJson())
                    .toList(),
                assets: (jsonDecode(map['assets'] as String) as List)
                    .map((a) => Asset.fromJson(a).toJson())
                    .toList(),
                submitted_at: map['submitted_at'] as int?,
                score: map['score'] as double?,
                remarks: map['remarks'] as String?,
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch answers: $e');
    }
  }

  Future<List<Answer>> getAnswersByLearner(String learnerId) async {
    try {
      final maps = await _db!
          .query('answers', where: 'learnerId = ?', whereArgs: [learnerId]);
      return maps
          .map((map) => Answer(
                id: map['id'] as String,
                questionId: map['questionId'] as String,
                learnerId: map['learnerId'] as String,
                strokes: (jsonDecode(map['strokes'] as String) as List)
                    .map((s) => Stroke.fromJson(s).toJson())
                    .toList(),
                assets: (jsonDecode(map['assets'] as String) as List)
                    .map((a) => Asset.fromJson(a).toJson())
                    .toList(),
                submitted_at: map['submitted_at'] as int?,
                score: map['score'] as double?,
                remarks: map['remarks'] as String?,
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch answers by learner: $e');
    }
  }

  Future<void> _queueSync(DatabaseExecutor txn, String table, String operation,
      Map<String, dynamic> data) async {
    try {
      await txn.insert('sync_pending', {
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
      final maps = await _db!.query('sync_pending',
          where: 'modified_at > ?', whereArgs: [sinceTimestamp]);
      return maps.map((map) {
        try {
          return {
            'id': map['id'],
            'table_name': map['table_name'],
            'operation': map['operation'],
            'data': jsonDecode(map['data'] as String),
            'modified_at': map['modified_at'],
          };
        } catch (e) {
          return {
            'id': map['id'],
            'table_name': map['table_name'],
            'operation': map['operation'],
            'data': {},
            'modified_at': map['modified_at'],
          };
        }
      }).toList();
    } catch (e) {
      throw Exception('Failed to fetch pending syncs: $e');
    }
  }

  Future<void> clearPendingSync(String id) async {
    try {
      await _db!.delete('sync_pending', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Failed to clear pending sync: $e');
    }
  }

  Future<void> updateLearnerTimetableStatus(
      String learnerId, String timetableId, String status) async {
    try {
      await _db!.transaction((txn) async {
        await txn.update(
          'learner_timetables',
          {'status': status},
          where: 'learnerId = ? AND id = ?',
          whereArgs: [learnerId, timetableId],
        );
        final updatedTimetable = Map<String, dynamic>.from((await txn.query(
                'learner_timetables',
                where: 'id = ?',
                whereArgs: [timetableId]))
            .first);
        await _queueSync(txn, 'learner_timetables', 'update',
            LearnerTimetable.fromMap(updatedTimetable).toMap());
      });
    } catch (e) {
      throw Exception('Failed to update learner timetable status: $e');
    }
  }

  Future<void> recordAttendance(
      String learnerId, String timetableId, String attendance, int date) async {
    try {
      await _db!.transaction((txn) async {
        await txn.update(
          'learner_timetables',
          {'attendance': attendance, 'attendanceDate': date},
          where: 'learnerId = ? AND id = ?',
          whereArgs: [learnerId, timetableId],
        );
        final updatedTimetable = Map<String, dynamic>.from((await txn.query(
                'learner_timetables',
                where: 'id = ?',
                whereArgs: [timetableId]))
            .first);
        await _queueSync(txn, 'learner_timetables', 'update',
            LearnerTimetable.fromMap(updatedTimetable).toMap());
      });
    } catch (e) {
      throw Exception('Failed to record attendance: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchStrokes(String learnerId) async {
    try {
      final timetables = await getLearnerTimetable(learnerId);
      if (timetables.isEmpty) return [];
      final timetable = timetables.firstWhere(
        (t) =>
            t.timeSlot.contains(DateTime.now().toIso8601String().split('T')[0]),
        orElse: () => timetables.first,
      );
      final questions = await getQuestionsByClass(timetable.classId);
      if (questions.isEmpty) {
        final question = Question(
          id: _uuid.v4(),
          timetableId: timetable.id,
          classId: timetable.classId,
          content: 'Default Canvas Question',
          pdfPage: 0,
        );
        await insertQuestion(question);
        questions.add(question);
      }
      final questionId = questions.first.id;
      final answers = await getAnswersByQuestion(questionId);
      final answer = answers.firstWhere(
        (a) => a.learnerId == learnerId,
        orElse: () => Answer(
          id: _uuid.v4(),
          questionId: questionId,
          learnerId: learnerId,
          strokes: [],
          assets: [],
        ),
      );
      if (answers.isEmpty || !answers.any((a) => a.learnerId == learnerId)) {
        await insertAnswer(answer);
      }
      return answer.strokes
          .map((s) => s['points'] != null ? s : {})
          .cast<Map<String, dynamic>>()
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch strokes: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAssets(String learnerId) async {
    try {
      final maps = await _db!.query(
        'assets',
        where: 'learnerId = ?',
        whereArgs: [learnerId],
      );
      return maps
          .map((map) => {
                'id': map['id'],
                'type': map['type'],
                'data': map['data'],
                'positionX': map['positionX'],
                'positionY': map['positionY'],
                'scale': map['scale'],
              })
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch assets: $e');
    }
  }

  Future<void> insertAsset(Asset asset) async {
    try {
      await _db!.transaction((txn) async {
        await txn.insert(
          'assets',
          {
            'id': asset.toJson()['id'] ?? _uuid.v4(),
            'learnerId': asset.toJson()['learnerId'],
            'questionId': asset.toJson()['questionId'],
            'type': asset.type,
            'data': asset.data,
            'positionX': 0.0,
            'positionY': 0.0,
            'scale': 1.0,
            'created_at': DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _queueSync(txn, 'assets', 'insert', asset.toJson());
      });
    } catch (e) {
      throw Exception('Failed to insert asset: $e');
    }
  }

  Future<List<Asset>> getAssetsByLearner(String learnerId) async {
    try {
      final maps = await _db!.query(
        'assets',
        where: 'learnerId = ?',
        whereArgs: [learnerId],
      );
      return maps.map((map) => Asset.fromJson(map)).toList();
    } catch (e) {
      throw Exception('Failed to fetch assets by learner: $e');
    }
  }

  Future<void> saveStrokes(String learnerId, List<Stroke> strokes) async {
    try {
      final timetables = await getLearnerTimetable(learnerId);
      if (timetables.isEmpty) return;
      final timetable = timetables.firstWhere(
        (t) =>
            t.timeSlot.contains(DateTime.now().toIso8601String().split('T')[0]),
        orElse: () => timetables.first,
      );
      final questions = await getQuestionsByClass(timetable.classId);
      if (questions.isEmpty) {
        final question = Question(
          id: _uuid.v4(),
          timetableId: timetable.id,
          classId: timetable.classId,
          content: 'Default Canvas Question',
          pdfPage: 0,
        );
        await insertQuestion(question);
        questions.add(question);
      }
      final questionId = questions.first.id;
      final answers = await getAnswersByQuestion(questionId);
      final answer = answers.firstWhere(
        (a) => a.learnerId == learnerId,
        orElse: () => Answer(
          id: _uuid.v4(),
          questionId: questionId,
          learnerId: learnerId,
          strokes: strokes.map((s) => s.toJson()).toList(),
          assets: [],
        ),
      );
      final updatedAnswer = Answer(
        id: answer.id,
        questionId: answer.questionId,
        learnerId: answer.learnerId,
        strokes: strokes.map((s) => s.toJson()).toList(),
        assets: answer.assets,
      );
      await _db!.transaction((txn) async {
        await txn.insert('answers', updatedAnswer.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        await _queueSync(txn, 'answers', 'update', updatedAnswer.toMap());
      });
    } catch (e) {
      throw Exception('Failed to save strokes: $e');
    }
  }

  Future<void> saveAssets(String learnerId, List<CanvasAsset> assets) async {
    try {
      final timetables = await getLearnerTimetable(learnerId);
      if (timetables.isEmpty) return;
      final timetable = timetables.firstWhere(
        (t) =>
            t.timeSlot.contains(DateTime.now().toIso8601String().split('T')[0]),
        orElse: () => timetables.first,
      );
      final questions = await getQuestionsByClass(timetable.classId);
      if (questions.isEmpty) {
        final question = Question(
          id: _uuid.v4(),
          timetableId: timetable.id,
          classId: timetable.classId,
          content: 'Default Canvas Question',
          pdfPage: 0,
        );
        await insertQuestion(question);
        questions.add(question);
      }
      final questionId = questions.first.id;
      final answers = await getAnswersByQuestion(questionId);
      final answer = answers.firstWhere(
        (a) => a.learnerId == learnerId,
        orElse: () => Answer(
          id: _uuid.v4(),
          questionId: questionId,
          learnerId: learnerId,
          strokes: [],
          assets:
              assets.map((a) => Asset.fromJson(a.toJson()).toJson()).toList(),
        ),
      );
      final updatedAnswer = Answer(
        id: answer.id,
        questionId: answer.questionId,
        learnerId: answer.learnerId,
        strokes: answer.strokes,
        assets: assets
            .map((a) => Asset(
                  id: a.id,
                  learnerId: learnerId,
                  questionId: questionId,
                  type: a.type,
                  data: a.path,
                  positionX: a.position.dx,
                  positionY: a.position.dy,
                  scale: a.scale,
                  created_at: DateTime.now().millisecondsSinceEpoch,
                ).toJson())
            .toList(),
      );
      await _db!.transaction((txn) async {
        await txn.insert('answers', updatedAnswer.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        await _queueSync(txn, 'answers', 'update', updatedAnswer.toMap());
      });
    } catch (e) {
      throw Exception('Failed to save assets: $e');
    }
  }

  Future<Map<String, dynamic>?> getClassById(String classId) async {
    try {
      final maps =
          await _db!.query('classes', where: 'id = ?', whereArgs: [classId]);
      return maps.isNotEmpty ? maps.first : null;
    } catch (e) {
      throw Exception('Failed to fetch class: $e');
    }
  }

  Future<void> insertData(String table, Map<String, dynamic> data,
      {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace}) async {
    try {
      await _db!.insert(table, data, conflictAlgorithm: conflictAlgorithm);
      await _queueSync(_db!, table, 'insert', data);
    } catch (e) {
      throw Exception('Failed to insert data into $table: $e');
    }
  }

  Future<void> insertAssessment(Assessment assessment) async {
    try {
      await _db!.transaction((txn) async {
        await txn.insert('assessments', assessment.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        await _queueSync(txn, 'assessments', 'insert', assessment.toMap());
      });
    } catch (e) {
      throw Exception('Failed to insert assessment: $e');
    }
  }

  Future<List<Assessment>> getAssessmentsByClass(String classId) async {
    try {
      final maps = await _db!.query('assessments',
          where: 'classIds LIKE ?', whereArgs: ['%$classId%']);
      return maps.map((map) => Assessment.fromMap(map)).toList();
    } catch (e) {
      throw Exception('Failed to fetch assessments: $e');
    }
  }

  Future<void> insertAnalytics(Analytics analytics) async {
    try {
      await _db!.transaction((txn) async {
        await txn.insert(
          'analytics',
          {
            'id': _uuid.v4(),
            'questionId': analytics.questionId,
            'learnerId': analytics.learnerId,
            'timeSpentSeconds': analytics.timeSpentSeconds,
            'submissionStatus': analytics.submissionStatus,
            'deviceId': analytics.deviceId,
            'timestamp':
                analytics.timestamp ?? DateTime.now().millisecondsSinceEpoch,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
        await _queueSync(txn, 'analytics', 'insert', analytics.toJson());
      });
    } catch (e) {
      throw Exception('Failed to insert analytics: $e');
    }
  }

  Future<List<Analytics>> getAnalyticsByLearner(String learnerId) async {
    try {
      final maps = await _db!.query(
        'analytics',
        where: 'learnerId = ?',
        whereArgs: [learnerId],
      );
      return maps.map((map) => Analytics.fromJson(map)).toList();
    } catch (e) {
      throw Exception('Failed to fetch analytics by learner: $e');
    }
  }
}
