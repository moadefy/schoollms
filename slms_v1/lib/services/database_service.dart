import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:schoollms/models/user.dart';
import 'package:schoollms/models/teacher.dart';
import 'package:schoollms/models/learner.dart';
import 'package:schoollms/models/teacher.model.dart';
import 'package:schoollms/models/learner.model.dart';
import 'package:schoollms/models/class.dart';
import 'package:schoollms/models/class.model.dart';
import 'package:schoollms/models/timetable.dart';
import 'package:schoollms/models/timetable_slot.dart';
import 'package:schoollms/models/timetable_slot_association.dart';
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
  static const int _baseVersion = 7; // Updated to current base version

  Future<void> init() async {
    print("Starting database initialization at ${DateTime.now()} SAST");
    final databasesPath = await getDatabasesPath();
    final path = '$databasesPath/schoollms.db';

    // Check if database exists and get its version
    int? existingVersion;
    try {
      final result = await _db?.rawQuery('PRAGMA user_version');
      existingVersion = result != null && result.isNotEmpty
          ? Sqflite.firstIntValue(result) ?? 0
          : 0;
      print("Existing database version: $existingVersion");
    } catch (e) {
      print("Error checking version: $e");
    }

    // Determine the new version
    int newVersion = _baseVersion;
    if (existingVersion != null && existingVersion > 0) {
      newVersion = existingVersion + 1; // Increment version on reinstall/update
      print("Upgrading to version: $newVersion");
    } else {
      print("Creating new database with version: $newVersion");
    }

    _db = await openDatabase(
      path,
      version: newVersion,
      onCreate: (db, version) async {
        print("Creating tables for version $version with db: $db");
        await _createTables(db);
        print("Seeding data with db: $db");
        await _seedData(db); // Pass db explicitly
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        print(
            "Upgrading database from $oldVersion to $newVersion with db: $db");
        await _migrateDatabase(db, oldVersion, newVersion);
      },
      onDowngrade: (db, oldVersion, newVersion) async {
        print(
            "Downgrading database from $oldVersion to $newVersion with db: $db");
        await _migrateDatabase(db, oldVersion, newVersion);
      },
    );
    print("Database initialized with version $newVersion, _db: $_db");
  }

  Future<void> _migrateDatabase(
      Database db, int oldVersion, int newVersion) async {
    try {
      // Migration from version 1 to 2 (hypothetical initial schema)
      if (oldVersion < 2) {
        await db.execute('ALTER TABLE timetables ADD COLUMN userRole TEXT');
        await db.execute('ALTER TABLE timetables ADD COLUMN userId TEXT');
        print("Added userRole and userId to timetables (v2)");
      }
      // Migration from version 2 to 3
      if (oldVersion < 3) {
        await db.execute('ALTER TABLE teachers ADD COLUMN timetableId TEXT');
        await db.execute('ALTER TABLE learners ADD COLUMN timetableId TEXT');
        print("Added timetableId to teachers and learners (v3)");
      }
      // Migration from version 3 to 4 (handle potential duplicate IDs or schema adjustments)
      if (oldVersion < 4) {
        // Optional: Add checks or adjustments for existing data if needed
        print(
            "Upgrading to version 4 - No schema changes, ensuring unique IDs");
      }
      // Update user_version to reflect the new version
      await db.execute('PRAGMA user_version = $newVersion');
    } catch (e) {
      print("Migration error: $e");
      rethrow; // Let the app crash with details for debugging
    }
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
    print("Creating TimetableSlot table");
    await TimetableSlot.createTable(db);
    print("Creating TimetableSlotAssociation table");
    await TimetableSlotAssociation.createTable(db);
    print("Creating LearnerTimetable table");
    await LearnerTimetable.createTable(db);
    print("Creating Question table");
    await Question.createTable(db);
    print("Creating Answer table");
    await Answer.createTable(db);
    print("Creating Assessment table");
    await Assessment.createTable(db);
    print("Creating LearnerData table");
    await LearnerData.createTable(db);
    print("Creating TeacherData table");
    await TeacherData.createTable(db);
    print("Creating User table");
    await User.createTable(db);
    print("Creating Assets table");
    await db.execute('''
    CREATE TABLE assets (
      id TEXT PRIMARY KEY,
      learnerId TEXT,
      questionId TEXT,
      type TEXT,
      data TEXT,
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
    print("Seeding data with database: $db");
    final teachersCount = Sqflite.firstIntValue(
        await db.query('teachers', columns: ['COUNT(*)']));
    if (teachersCount == 0) {
      print("Seeding Teachers");
      await db.insert(
          'teachers',
          Teacher(id: 'teacher_1', name: 'Ms. Smith', timetableId: null)
              .toMap());
      await db.insert(
          'teachers',
          Teacher(id: 'teacher_2', name: 'Mr. Jones', timetableId: null)
              .toMap());

      print("Seeding Learners");
      await db.insert(
          'learners',
          Learner(
                  id: 'learner_1',
                  name: 'Alice',
                  grade: '10',
                  timetableId: null)
              .toMap());
      await db.insert(
          'learners',
          Learner(id: 'learner_2', name: 'Bob', grade: '10', timetableId: null)
              .toMap());
      await db.insert(
          'learners',
          Learner(
                  id: 'learner_3',
                  name: 'Charlie',
                  grade: '11',
                  timetableId: null)
              .toMap());
      await db.insert(
          'learners',
          Learner(
                  id: 'learner_4',
                  name: 'David',
                  grade: '11',
                  timetableId: null)
              .toMap());
      await db.insert(
          'learners',
          Learner(id: 'learner_5', name: 'Eve', grade: '10', timetableId: null)
              .toMap());

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

      print("Seeding Timetables and TimetableSlots");
      // Teacher 1 Timetable and Slots
      final teacher1Timetable = Timetable(
          id: _uuid.v4(),
          teacherId: 'teacher_1',
          userId: 'teacher_1',
          userRole: 'teacher');
      final seedDate = DateTime.now().toIso8601String().split('T')[0];
      await insertTimetable(
          teacher1Timetable,
          [
            {
              'id': _uuid.v4(),
              'classId': 'class_1',
              'timeSlot': '$seedDate 09:00-10:00',
              'learnerIds': ['learner_1', 'learner_2', 'learner_5'],
            },
            {
              'id': _uuid.v4(),
              'classId': 'class_1',
              'timeSlot': '$seedDate 10:00-11:00',
              'learnerIds': ['learner_1', 'learner_2', 'learner_5'],
            },
            {
              'id': _uuid.v4(),
              'classId': 'class_2',
              'timeSlot': '$seedDate 11:00-12:00',
              'learnerIds': ['learner_1', 'learner_2', 'learner_5'],
            },
          ],
          db);

      // Teacher 2 Timetable and Slots
      final teacher2Timetable = Timetable(
          id: _uuid.v4(),
          teacherId: 'teacher_2',
          userId: 'teacher_2',
          userRole: 'teacher');
      await insertTimetable(
          teacher2Timetable,
          [
            {
              'id': _uuid.v4(),
              'classId': 'class_3',
              'timeSlot': '$seedDate 13:00-14:00',
              'learnerIds': ['learner_3', 'learner_4'],
            },
            {
              'id': _uuid.v4(),
              'classId': 'class_3',
              'timeSlot': '$seedDate 14:00-15:00',
              'learnerIds': ['learner_3', 'learner_4'],
            },
          ],
          db);

      print("Registering Learner Devices");
      await _registerLearnerDevice(
          db, 'learner_1', 'device_1', 'teacher_1', 'class_1');
      await _registerLearnerDevice(
          db, 'learner_2', 'device_2', 'teacher_1', 'class_1');
      await _registerLearnerDevice(
          db, 'learner_3', 'device_3', 'teacher_2', 'class_3');
      await _registerLearnerDevice(
          db, 'learner_4', 'device_4', 'teacher_2', 'class_3');
      await _registerLearnerDevice(
          db, 'learner_5', 'device_5', 'teacher_1', 'class_2');
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

  Future<String?> validateTimetable(
      Timetable timetable, List<Map<String, dynamic>> slots,
      [Database? db]) async {
    final database = db ?? _db;
    if (database == null) {
      return 'Database not initialized';
    }
    try {
      print(
          "Validating timetable: ${timetable.toMap()} with ${slots.length} slots");
      if (timetable.id == null) {
        return 'Timetable ID cannot be null';
      }
      if (timetable.teacherId == null) {
        return 'Teacher ID cannot be null';
      }
      if (slots == null || slots.isEmpty) {
        return 'At least one timetable slot is required';
      }

      final existingSlots = await database.query('timetable_slots') ?? [];
      print("Found ${existingSlots.length} existing slots");

      for (final newSlot in slots) {
        print("Validating slot: $newSlot");
        final timeSlot = newSlot['timeSlot'] as String?;
        if (timeSlot == null) return 'Invalid time slot: null value';
        final newTimeParts = timeSlot.split(' ');
        print("Time parts: $newTimeParts");
        if (newTimeParts.length < 2)
          return 'Invalid time slot format (expected date and time)';
        final date = newTimeParts[0];
        final timeRange = newTimeParts.length > 1 ? newTimeParts[1] : '';
        final times = timeRange.split('-');
        if (times.length != 2 || times[0].isEmpty || times[1].isEmpty)
          return 'Invalid time range';
        final startTime = times[0].split(':');
        final endTime = times[1].split(':');
        if (startTime.length != 2 ||
            endTime.length != 2 ||
            startTime[0].isEmpty ||
            startTime[1].isEmpty ||
            endTime[0].isEmpty ||
            endTime[1].isEmpty) {
          return 'Invalid time format';
        }

        final startHour = int.tryParse(startTime[0]) ?? -1;
        final endHour = int.tryParse(endTime[0]) ?? -1;
        final startMinute = int.tryParse(startTime[1]) ?? -1;
        final endMinute = int.tryParse(endTime[1]) ?? -1;
        print(
            "Parsed times - Start: $startHour:$startMinute, End: $endHour:$endMinute");
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

        final classId = newSlot['classId'] as String?;
        if (classId == null) return 'Invalid class ID: null value';
        final classData = await database
            .query('classes', where: 'id = ?', whereArgs: [classId]);
        print("Class data for $classId: $classData");
        if (classData.isEmpty) return 'Invalid class ID';

        for (final existingSlot in existingSlots) {
          final existingTimeSlot = existingSlot['timeSlot'] as String?;
          final existingClassId = existingSlot['classId'] as String?;
          if (existingTimeSlot != null &&
              existingClassId != null &&
              classId == existingClassId &&
              timeSlot == existingTimeSlot) {
            return 'Time slot and class overlap with existing schedule';
          }
        }

        // Learner conflict check
        final learnerIds =
            (newSlot['learnerIds'] as List?)?.cast<String>() ?? [];
        if (learnerIds.isEmpty) return 'No learner IDs provided';
        final classGrade =
            classData.isNotEmpty ? classData[0]['grade'] as String? : null;
        if (classGrade == null) return 'Class grade is null';
        for (final learnerId in learnerIds) {
          final learnerData = await database
              .query('learners', where: 'id = ?', whereArgs: [learnerId]);
          print("Learner data for $learnerId: $learnerData");
          if (learnerData.isEmpty ||
              (learnerData[0]['grade'] as String?) != classGrade) {
            return 'Learner $learnerId does not match class grade $classGrade';
          }
          final learnerSlots = await database.query('timetable_slots',
              where: 'learnerIds LIKE ? AND timeSlot LIKE ?',
              whereArgs: ['%$learnerId%', '$date%']);
          for (final ls in learnerSlots) {
            final lsSlot = ls['timeSlot'] as String?;
            if (lsSlot != null && timeSlot == lsSlot) {
              return 'Learner $learnerId has a conflicting schedule at $lsSlot';
            }
          }
        }
      }

      return null;
    } catch (e) {
      print("Validation exception: $e");
      return 'Validation error: $e';
    }
  }

  Future<void> insertTeacher(Teacher teacher) async {
    try {
      await _db!.transaction((txn) async {
        await txn.insert('teachers', teacher.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        if (teacher.timetableId != null) {
          await txn.update(
              'timetables', {'userId': teacher.id, 'userRole': 'teacher'},
              where: 'id = ?', whereArgs: [teacher.timetableId]);
        }
        await _queueSync(txn, 'teachers', 'insert', teacher.toMap());
      });
    } catch (e) {
      throw Exception('Failed to insert teacher: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllTimetableSlots() async {
    try {
      print("Fetching all timetable slots");
      final maps = await _db!.rawQuery('''
        SELECT ts.id AS slot_id, tsa.timetableId, ts.classId, ts.timeSlot, ts.learnerIds,
               c.subject, c.grade
        FROM timetables t
        JOIN timetable_slot_association tsa ON t.id = tsa.timetableId
        JOIN timetable_slots ts ON tsa.slotId = ts.id
        JOIN classes c ON ts.classId = c.id
        WHERE t.userRole IN ('teacher', 'admin')
        ORDER BY ts.timeSlot
      ''');
      print("All timetable slots query result: $maps");
      return maps;
    } catch (e) {
      print("Error fetching all timetable slots: $e");
      throw Exception('Failed to fetch all timetable slots: $e');
    }
  }

  Future<void> insertLearnerData(LearnerData learner) async =>
      await _db!.insert('learnerdata', learner.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> insertTeacherData(TeacherData teacher) async =>
      await _db!.insert('teacherdata', teacher.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<void> insertUser(User user) async =>
      await _db!.insert('users', user.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);

  Future<TeacherData?> getTeacherDataByIdFromCitizenship(
      String country, String citizenshipId) async {
    try {
      final maps = await _db!.query(
        'teacherdata',
        where: 'country = ? AND citizenshipId = ?',
        whereArgs: [country, citizenshipId],
      );
      if (maps.isEmpty) return null;
      print("Retrieved teacher data: ${maps.first}"); // Debug log
      return TeacherData.fromMap(maps.first);
    } catch (e) {
      print("Error fetching teacher data by citizenship: $e");
      return null;
    }
  }

  Future<LearnerData?> getLearnerDataByIdFromCitizenship(
      String country, String citizenshipId) async {
    try {
      final maps = await _db!.query(
        'learnerdata',
        where: 'country = ? AND citizenshipId = ?',
        whereArgs: [country, citizenshipId],
      );
      if (maps.isEmpty) return null;
      return LearnerData.fromMap(maps.first);
    } catch (e) {
      print("Error fetching learner data by citizenship: $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> getUserByCitizenship(
      String country, String citizenshipId) async {
    try {
      final tables = [
        'learnerdata',
        'teacherdata',
        'users'
      ]; // Assume 'users' for parent/admin
      for (var table in tables) {
        final maps = await _db!.query(
          table,
          where: 'country = ? AND citizenshipId = ?',
          whereArgs: [country, citizenshipId],
        );
        if (maps.isNotEmpty) return maps.first;
      }
      return null;
    } catch (e) {
      print("Error fetching user by citizenship: $e");
      return null;
    }
  }

  Future<void> syncDataWithTeacher(String teacherCountry,
      String teacherCitizenshipId, BuildContext context) async {
    try {
      // Placeholder for sync logic
      final teachers = await _db!.query(
        'teacherdata',
        where: 'country = ? AND citizenshipId = ?',
        whereArgs: [teacherCountry, teacherCitizenshipId],
      );
      if (teachers.isNotEmpty) {
        final teacherId = teachers.first['id'] as String;
        final learners = await _db!.query(
          'learnerdata',
          where: 'country = ?', // Match teacher's country for now
          whereArgs: [teacherCountry],
        );
        // Simulate sync by logging or preparing data
        print(
            "Synced data for teacher $teacherId: ${learners.length} learners");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data synced with teacher credentials')),
        );
      } else {
        print("No teacher found with given credentials");
      }
    } catch (e) {
      print("Sync error: $e");
    }
  }

  Future<Map<String, dynamic>?> getUserById(String id) async =>
      (await _db!.query('users', where: 'id = ?', whereArgs: [id])).firstOrNull;

  Future<List<Map<String, dynamic>>> getAllUsers() async =>
      await _db!.query('users');

  Future<LearnerData?> getLearnerDataById(String id) async {
    try {
      final maps = await _db!.query(
        'learnerdata',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isEmpty) return null;
      return LearnerData.fromMap(maps.first);
    } catch (e) {
      print("Error fetching learner data by ID: $e");
      return null;
    }
  }

  Future<void> updateLearnerData(LearnerData learner) async =>
      await _db!.update('learnerdata', learner.toMap(),
          where: 'id = ?', whereArgs: [learner.id]);

  Future<void> insertLearner(Learner learner) async {
    try {
      await _db!.transaction((txn) async {
        await txn.insert('learners', learner.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        if (learner.timetableId != null) {
          await txn.update(
              'timetables', {'userId': learner.id, 'userRole': 'learner'},
              where: 'id = ?', whereArgs: [learner.timetableId]);
        }
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
                timetableId: map['timetableId'] as String?,
              ))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch learners: $e');
    }
  }

  Future<void> insertClassData(ClassData classData) async {
    try {
      await _db!.insert('classdata', classData.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('Error inserting class data: $e');
      throw e;
    }
  }

  Future<ClassData> getClassDataById(String id) async {
    try {
      final maps = await _db!.query(
        'classdata',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isNotEmpty) {
        return ClassData.fromMap(maps.first);
      }
      throw Exception('ClassData not found');
    } catch (e) {
      print('Error fetching class data by ID: $e');
      throw e;
    }
  }

  Future<List<ClassData>> getTeacherClassDataByTeacherId(
      String teacherId) async {
    try {
      final maps = await _db!.query(
        'classdata',
        where: 'teacherId = ?',
        whereArgs: [teacherId],
      );
      return maps.map((map) => ClassData.fromMap(map)).toList();
    } catch (e) {
      print('Error fetching teacher class data: $e');
      return [];
    }
  }

  // Method to update learnerIds when assigning learners to a class
  Future<void> updateClassLearnerIds(
      String classId, List<String> learnerIds) async {
    try {
      final classData = await getClassDataById(classId);
      final updatedClass = classData.copyWith(learnerIds: learnerIds);
      await _db!.update(
        'classdata',
        updatedClass.toMap(),
        where: 'id = ?',
        whereArgs: [classId],
      );
    } catch (e) {
      print('Error updating class learner IDs: $e');
      throw e;
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

  Future<void> insertTimetable(
      Timetable timetable, List<Map<String, dynamic>> slots,
      [Database? db]) async {
    final database = db ?? _db;
    if (database == null) {
      throw Exception('Database not initialized');
    }
    try {
      // Validate the timetable and slots
      final validationError =
          await validateTimetable(timetable, slots, database);
      if (validationError != null) throw Exception(validationError);

      Map<String, dynamic> timetableData = timetable.toMap();
      if (timetable.userRole == null) timetableData['userRole'] = 'teacher';
      if (timetable.userId == null && timetableData['userRole'] == 'teacher') {
        timetableData['userId'] = timetable.teacherId;
      }

      // Check for existing timetable for the teacher
      final existingTimetable = await database.query('timetables',
          where: 'userId = ? AND userRole = ?',
          whereArgs: [timetableData['userId'], timetableData['userRole']],
          limit: 1);
      if (existingTimetable.isNotEmpty) {
        timetableData['id'] = existingTimetable.first['id'] as String;
      } else {
        timetableData['id'] = _uuid.v4();
      }

      // Update teacher's timetableId
      if (timetableData['userRole'] == 'teacher') {
        await database.update('teachers', {'timetableId': timetableData['id']},
            where: 'id = ?', whereArgs: [timetable.teacherId]);
      }

      await database.transaction((txn) async {
        // Insert or update the timetable
        await txn.insert('timetables', timetableData,
            conflictAlgorithm: ConflictAlgorithm.replace);
        await _queueSync(txn, 'timetables', 'insert', timetableData);

        // Insert TimetableSlot entries for each slot with class association
        List<String> slotIds = [];
        for (final slot in slots) {
          final slotId = slot['id'] as String? ?? _uuid.v4();
          final classId = slot['classId'] as String?;
          final timeSlot = slot['timeSlot'] as String?;
          final learnerIds =
              (slot['learnerIds'] as List?)?.cast<String>() ?? [];

          if (classId == null || timeSlot == null) {
            throw Exception(
                'Invalid slot data: classId and timeSlot are required');
          }

          final timetableSlot = TimetableSlot(
            id: slotId,
            classId: classId,
            timeSlot: timeSlot,
            learnerIds: learnerIds,
          );
          await txn.insert('timetable_slots', timetableSlot.toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
          await _queueSync(
              txn, 'timetable_slots', 'insert', timetableSlot.toMap());
          slotIds.add(slotId);

          // Update learners' timetableId
          for (final learnerId in learnerIds) {
            await txn.update('learners', {'timetableId': timetableData['id']},
                where: 'id = ?', whereArgs: [learnerId]);
          }
        }

        // Associate teacher with slots
        if (slotIds.isNotEmpty) {
          final teacherAssociationId = _uuid.v4();
          await txn.insert(
              'timetable_slot_association',
              TimetableSlotAssociation(
                      id: teacherAssociationId,
                      userId: timetable.teacherId,
                      timetableId: timetableData['id'],
                      slotId: slotIds[0])
                  .toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
          await _queueSync(
              txn,
              'timetable_slot_association',
              'insert',
              TimetableSlotAssociation(
                      id: teacherAssociationId,
                      userId: timetable.teacherId,
                      timetableId: timetableData['id'],
                      slotId: slotIds[0])
                  .toMap());
        }

        // Associate learners with slots
        for (final slot in slots) {
          final slotIndex = slots.indexOf(slot);
          final slotId = slotIds[slotIndex];
          final learnerIds =
              (slot['learnerIds'] as List?)?.cast<String>() ?? [];
          for (final learnerId in learnerIds) {
            final associationId = _uuid.v4();
            await txn.insert(
                'timetable_slot_association',
                TimetableSlotAssociation(
                        id: associationId,
                        userId: learnerId,
                        timetableId: timetableData['id'],
                        slotId: slotId)
                    .toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
            await _queueSync(
                txn,
                'timetable_slot_association',
                'insert',
                TimetableSlotAssociation(
                        id: associationId,
                        userId: learnerId,
                        timetableId: timetableData['id'],
                        slotId: slotId)
                    .toMap());
          }
        }

        // Generate LearnerTimetables based on TimetableSlots
        await _generateLearnerTimetables(txn, Timetable.fromMap(timetableData));
      });
    } catch (e) {
      throw Exception('Failed to insert timetable: $e');
    }
  }

  Future<List<Timetable>> getTimetables(String classId) async {
    try {
      final maps = await _db!.rawQuery('''
      SELECT t.id AS timetable_id, t.teacherId, t.userId, t.userRole, ts.id AS slot_id, ts.classId, ts.timeSlot, ts.learnerIds
      FROM timetables t
      JOIN timetable_slot_association tsa ON t.id = tsa.timetableId
      JOIN timetable_slots ts ON tsa.slotId = ts.id
      WHERE ts.classId = ? AND t.userRole = 'teacher'
      ORDER BY ts.timeSlot
    ''', [classId]);
      final timetables = <Timetable>{}; // Use Set to avoid duplicates
      for (final map in maps) {
        final timetable = Timetable(
          id: map['timetable_id'] as String,
          teacherId: map['teacherId'] as String,
          userId: map['userId'] as String?,
          userRole: map['userRole'] as String?,
        );
        timetables.add(timetable); // Add unique timetable
      }
      return timetables.toList();
    } catch (e) {
      throw Exception('Failed to fetch timetables: $e');
    }
  }

  Future<void> _generateLearnerTimetables(
      DatabaseExecutor txn, Timetable timetable) async {
    try {
      // Fetch all slots associated with this timetable
      final slotAssociations = await txn.query('timetable_slot_association',
          where: 'timetableId = ?', whereArgs: [timetable.id]);
      for (final association in slotAssociations) {
        final slotId = association['slotId'] as String;
        final slot = await txn.query('timetable_slots',
            where: 'id = ?', whereArgs: [slotId], limit: 1);
        if (slot.isNotEmpty) {
          final learnerIds = (slot[0]['learnerIds'] as String).split(',');
          for (final learnerId in learnerIds) {
            final learnerTimetable = LearnerTimetable(
              id: _uuid.v4(),
              learnerId: learnerId,
              classId: slot[0]['classId'] as String,
              timeSlot: slot[0]['timeSlot'] as String,
              status: 'active',
            );
            await txn.insert('learner_timetables', learnerTimetable.toMap(),
                conflictAlgorithm: ConflictAlgorithm.replace);
            await _queueSync(
                txn, 'learner_timetables', 'insert', learnerTimetable.toMap());
          }
        }
      }
    } catch (e) {
      throw Exception('Failed to generate learner timetables: $e');
    }
  }

  Future<List<LearnerTimetable>> getLearnerTimetable(String learnerId,
      {int sinceTimestamp = 0}) async {
    try {
      final maps = await _db!.rawQuery('''
      SELECT lt.id, lt.learnerId, ts.classId, ts.timeSlot, lt.status, lt.attendance, lt.attendanceDate, lt.modified_at
      FROM learner_timetables lt
      JOIN timetable_slots ts ON lt.classId = ts.classId AND lt.timeSlot = ts.timeSlot
      WHERE lt.learnerId = ? AND (lt.modified_at IS NULL OR lt.modified_at > ?)
    ''', [learnerId, sinceTimestamp]);
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
      // Validate against existing timetable_slots
      final existingSlot = await _db!.query('timetable_slots',
          where: 'classId = ? AND timeSlot = ?',
          whereArgs: [learnerTimetable.classId, learnerTimetable.timeSlot],
          limit: 1);
      if (existingSlot.isEmpty) {
        throw Exception('Invalid classId or timeSlot combination');
      }

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

  Future<List<TimetableSlot>> getTimetableSlotsByTimetableId(
      String timetableId) async {
    try {
      final maps = await _db!.query(
        'timetable_slots',
        where:
            'id IN (SELECT slotId FROM timetable_slot_association WHERE timetableId = ?)',
        whereArgs: [timetableId],
      );
      return maps
          .map((map) => TimetableSlot(
                id: map['id'] as String,
                classId: map['classId'] as String,
                timeSlot: map['timeSlot'] as String,
                learnerIds: (map['learnerIds'] as String).split(','),
              ))
          .toList();
    } catch (e) {
      print('Error fetching timetable slots for timetableId $timetableId: $e');
      throw Exception('Failed to fetch timetable slots: $e');
    }
  }

  Future<List<TimetableSlotAssociation>>
      getTimetableSlotAssociationsByTimetableId(String timetableId) async {
    try {
      final maps = await _db!.query(
        'timetable_slot_association',
        where: 'timetableId = ?',
        whereArgs: [timetableId],
      );
      return maps
          .map((map) => TimetableSlotAssociation(
                id: map['id'] as String,
                userId: map['userId'] as String,
                timetableId: map['timetableId'] as String,
                slotId: map['slotId'] as String,
              ))
          .toList();
    } catch (e) {
      print(
          'Error fetching timetable slot associations for timetableId $timetableId: $e');
      throw Exception('Failed to fetch timetable slot associations: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getTeacherTimetableSlots(
      String teacherId) async {
    try {
      print("Fetching timetable slots for teacherId: $teacherId");
      final maps = await _db!.rawQuery('''
      SELECT DISTINCT ts.id AS slot_id, tsa.timetableId, ts.classId, ts.timeSlot, ts.learnerIds,
             c.subject, c.grade
      FROM timetables t
      JOIN timetable_slot_association tsa ON t.id = tsa.timetableId
      JOIN timetable_slots ts ON tsa.slotId = ts.id
      JOIN classes c ON ts.classId = c.id
      WHERE t.teacherId = ? AND t.userRole = 'teacher'
      ORDER BY ts.timeSlot
    ''', [teacherId]);
      print("Teacher timetable slots query result: $maps");
      return maps;
    } catch (e) {
      print("Error fetching teacher timetable slots: $e");
      throw Exception('Failed to fetch teacher timetable slots: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getLearnerTimetableSlots(
      String learnerId) async {
    try {
      print("Fetching timetable slots for learnerId: $learnerId");
      final maps = await _db!.rawQuery('''
      SELECT ts.id AS slot_id, ts.classId, ts.timeSlot, ts.learnerIds,
             c.subject, c.grade
      FROM learner_timetables lt
      JOIN timetable_slots ts ON lt.classId = ts.classId AND lt.timeSlot = ts.timeSlot
      JOIN classes c ON ts.classId = c.id
      WHERE lt.learnerId = ?
      ORDER BY ts.timeSlot
    ''', [learnerId]);
      print("Learner timetable slots query result: $maps");
      return maps;
    } catch (e) {
      print("Error fetching learner timetable slots: $e");
      throw Exception('Failed to fetch learner timetable slots: $e');
    }
  }
}
