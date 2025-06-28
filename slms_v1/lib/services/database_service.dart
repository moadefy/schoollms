import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import 'package:schoollms/models/user.dart';
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
import 'package:schoollms/models/subject.dart';
import 'package:schoollms/models/grade.dart';
import 'package:schoollms/models/language.dart';
import 'package:schoollms/widgets/canvas_widget.dart';

class DatabaseService {
  Database? _db;
  final _uuid = const Uuid();
  static const int _baseVersion = 29;
  bool _isInitialized = false;

  Future<void> init() async {
    print("Starting database initialization at ${DateTime.now()} SAST");
    final databasesPath = await getDatabasesPath();
    final path = '$databasesPath/schoollms.db';

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

    int newVersion = _baseVersion;
    if (existingVersion != null && existingVersion > 0) {
      newVersion = existingVersion + 1;
      print("Upgrading to version: $newVersion");
    } else {
      print("Creating new database with version: $newVersion");
    }

    try {
      _db = await openDatabase(
        path,
        version: newVersion,
        onCreate: (db, version) async {
          print("Creating tables for version $version with db: $db");
          await _createTables(db);
          print("Seeding data with db: $db");
          await _seedData(db);
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
      _isInitialized = true;
      print("Database initialized with version $newVersion, _db: $_db");
      // Verify seed data after initialization
      final subjectCount = Sqflite.firstIntValue(
              await _db!.query('subjects', columns: ['COUNT(*)'])) ??
          0;
      final gradeCount = Sqflite.firstIntValue(
              await _db!.query('grades', columns: ['COUNT(*)'])) ??
          0;
      print(
          "Verified subjects count: $subjectCount, grades count: $gradeCount");
    } catch (e) {
      print("Database initialization failed: $e");
      _isInitialized = false;
      rethrow;
    }
  }

  Future<void> _migrateDatabase(
      Database db, int oldVersion, int newVersion) async {
    try {
      if (oldVersion < 2) {
        await db.execute('ALTER TABLE timetables ADD COLUMN userRole TEXT');
        await db.execute('ALTER TABLE timetables ADD COLUMN userId TEXT');
        print("Added userRole and userId to timetables (v2)");
      }
      if (oldVersion < 3) {
        await db.execute('ALTER TABLE classes RENAME TO classdata');
        print("Renamed classes to classdata (v3)");
      }
      if (oldVersion < 4) {
        await db.execute('DROP TABLE IF EXISTS teachers');
        await db.execute('DROP TABLE IF EXISTS learners');
        await db.execute('DROP TABLE IF EXISTS teacherdata');
        await db.execute('DROP TABLE IF EXISTS learnerdata');
        print("Dropped redundant tables (v4)");
      }
      if (oldVersion < 5) {
        await db
            .execute('ALTER TABLE timetable_slots ADD COLUMN learnerIds TEXT');
        print("Added learnerIds to timetable_slots (v5)");
      }
      if (oldVersion < 6) {
        await db.execute(
            'ALTER TABLE timetable_slot_association DROP COLUMN userId');
        await db.execute(
            'ALTER TABLE timetable_slot_association ADD COLUMN userId TEXT');
        await db.execute(
            'ALTER TABLE timetable_slot_association ADD CONSTRAINT fk_user FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE');
        print("Updated timetable_slot_association for users table (v6)");
      }
      if (oldVersion < 7) {
        await db.execute('ALTER TABLE users ADD COLUMN roleData TEXT');
        print("Added roleData to users table (v7)");
      }
      if (oldVersion < 8) {
        await db.execute(
            'ALTER TABLE timetable_slot_association DROP CONSTRAINT fk_user');
        await db.execute(
            'ALTER TABLE timetable_slot_association ADD CONSTRAINT fk_user FOREIGN KEY (userId) REFERENCES users(id) ON DELETE CASCADE');
        print(
            "Recreated fk_user constraint in timetable_slot_association (v8)");
      }
      if (oldVersion < 9) {
        await db.execute('ALTER TABLE analytics ADD COLUMN timetableId TEXT');
        await db.execute('ALTER TABLE analytics ADD COLUMN slotId TEXT');
        print("Added timetableId and slotId to analytics (v9)");
      }
      if (oldVersion < 10) {
        await db.execute('ALTER TABLE classdata DROP COLUMN subject');
        await db.execute('ALTER TABLE classdata DROP COLUMN grade');
        await db.execute('ALTER TABLE classdata ADD COLUMN subjectId TEXT');
        await db.execute('ALTER TABLE classdata ADD COLUMN gradeId TEXT');
        await db.execute(
            'ALTER TABLE classdata ADD CONSTRAINT fk_subject FOREIGN KEY (subjectId) REFERENCES subjects(id) ON DELETE RESTRICT');
        await db.execute(
            'ALTER TABLE classdata ADD CONSTRAINT fk_grade FOREIGN KEY (gradeId) REFERENCES grades(id) ON DELETE RESTRICT');
        await db.execute('ALTER TABLE classdata DROP CONSTRAINT fk_teacher');
        await db.execute(
            'ALTER TABLE classdata ADD CONSTRAINT fk_teacher FOREIGN KEY (teacherId) REFERENCES users(id) ON DELETE CASCADE');
        print("Updated classdata schema with subjectId and gradeId (v10)");
      }
      if (oldVersion < 11) {
        await db.execute('ALTER TABLE users ADD COLUMN homeLanguageId TEXT');
        await db
            .execute('ALTER TABLE users ADD COLUMN preferredLanguageId TEXT');
        await db.execute(
            'ALTER TABLE users ADD CONSTRAINT fk_homeLanguage FOREIGN KEY (homeLanguageId) REFERENCES languages(id) ON DELETE SET NULL');
        await db.execute(
            'ALTER TABLE users ADD CONSTRAINT fk_preferredLanguage FOREIGN KEY (preferredLanguageId) REFERENCES languages(id) ON DELETE SET NULL');
        print("Added language fields to users table (v11)");
      }
      if (oldVersion < 12) {
        /*await db.execute('UPDATE users SET roleData = json_patch(roleData, json(?) WHERE role = ?', [
          jsonEncode({'qualifiedSubjects': jsonDecode(roleData ?? '{}')['qualifiedSubjects'] ?? {}}),
          'teacher'
        ]);
        await db.execute('UPDATE users SET roleData = json_patch(roleData, json(?) WHERE role = ?', [
          jsonEncode({'selectedGrade': jsonDecode(roleData ?? '{}')['grade'], 'selectedSubjects': jsonDecode(roleData ?? '{}')['subjects'] ?? []}),
          'learner'
        ]);
        print("Normalized roleData for teacher and learner roles (v12)");*/
      }
      if (oldVersion < 13) {
        await db.execute('ALTER TABLE users DROP COLUMN roleData');
        await db.execute('ALTER TABLE users ADD COLUMN roleData TEXT');
        print("Recreated roleData column to ensure proper JSON storage (v13)");
      }
      if (oldVersion < 14) {
        await db.execute(
            'ALTER TABLE timetable_slots ADD COLUMN slotType TEXT DEFAULT "standard"');
        print("Added slotType to timetable_slots (v14)");
      }
      if (oldVersion < 15) {
        print("Ensuring seed data for new models (v15)");
      }
      await db.execute('PRAGMA user_version = $newVersion');
    } catch (e) {
      print("Migration error: $e");
      rethrow;
    }
  }

  Future<void> _createTables(Database db) async {
    print("Creating User table");
    await User.createTable(db);
    print("Creating Subject table");
    await Subject.createTable(db);
    print("Creating Grade table");
    await Grade.createTable(db);
    print("Creating Language table");
    await Language.createTable(db);
    print("Creating ClassData table");
    await ClassData.createTable(db);
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
      timestamp INTEGER,
      timetableId TEXT,
      slotId TEXT
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
    await db.transaction((txn) async {
      final usersCountResult = await txn.query('users', columns: ['COUNT(*)']);
      final usersCount = usersCountResult.isNotEmpty
          ? (usersCountResult.first['COUNT(*)'] as int? ?? 0)
          : 0;
      print("Users count: $usersCount");
      if (usersCount == 0) {
        print("Seeding Grades");
        for (int i = 0; i <= 12; i++) {
          final gradeId = _uuid.v4();
          await txn.insert('grades',
              Grade(id: gradeId, number: i == 0 ? 'R' : i.toString()).toMap());
        }

        print("Seeding Subjects");
        final subjectGradeMap = <String, List<String>>{
          'Accounting': ['10', '11', '12'],
          'Afrikaans': [
            'R',
            '1',
            '2',
            '3',
            '4',
            '5',
            '6',
            '7',
            '8',
            '9',
            '10',
            '11',
            '12'
          ],
          'Agricultural Sciences': ['10', '11', '12'],
          'Agricultural Management Practices': ['10', '11', '12'],
          'Agricultural Technology': ['10', '11', '12'],
          'Application Sciences': ['10', '11', '12'],
          'Artificial Intelligences': ['10', '11', '12'],
          'Arts and Culture': ['7', '8', '9'],
          'Business Studies': ['10', '11', '12'],
          'Civil Technology': ['10', '11', '12'],
          'Coding': [
            'R',
            '1',
            '2',
            '3',
            '4',
            '5',
            '6',
            '7',
            '8',
            '9',
            '10',
            '11',
            '12'
          ],
          'Consumer Studies': ['10', '11', '12'],
          'Computer Application Technology': ['10', '11', '12'],
          'Dance Studies': ['10', '11', '12'],
          'Data Sciences': ['10', '11', '12'],
          'Design': ['10', '11', '12'],
          'Dramatic Arts': ['10', '11', '12'],
          'Economic and Management Sciences': ['7', '8', '9'],
          'Economics': ['10', '11', '12'],
          'Electrical Technology': ['10', '11', '12'],
          'Engineering and Graphic Design': ['10', '11', '12'],
          'English': [
            'R',
            '1',
            '2',
            '3',
            '4',
            '5',
            '6',
            '7',
            '8',
            '9',
            '10',
            '11',
            '12'
          ],
          'Geography': ['10', '11', '12'],
          'History': ['10', '11', '12'],
          'Hospitality Studies': ['10', '11', '12'],
          'Information Technology': ['10', '11', '12'],
          'Innovation': [
            'R',
            '1',
            '2',
            '3',
            '4',
            '5',
            '6',
            '7',
            '8',
            '9',
            '10',
            '11',
            '12'
          ],
          'IsiNdebele': [
            'R',
            '1',
            '2',
            '3',
            '4',
            '5',
            '6',
            '7',
            '8',
            '9',
            '10',
            '11',
            '12'
          ],
          'IsiXhosa': [
            'R',
            '1',
            '2',
            '3',
            '4',
            '5',
            '6',
            '7',
            '8',
            '9',
            '10',
            '11',
            '12'
          ],
          'IsiZulu': [
            'R',
            '1',
            '2',
            '3',
            '4',
            '5',
            '6',
            '7',
            '8',
            '9',
            '10',
            '11',
            '12'
          ],
          'Life Orientation': ['7', '8', '9', '10', '11', '12'],
          'Life Sciences': ['10', '11', '12'],
          'Life Skills': ['R', '1', '2', '3', '4', '5', '6'],
          'Mathematical Literacy': ['10', '11', '12'],
          'Mathematics': [
            'R',
            '1',
            '2',
            '3',
            '4',
            '5',
            '6',
            '7',
            '8',
            '9',
            '10',
            '11',
            '12'
          ],
          'Mechanical Technology': ['10', '11', '12'],
          'Music': ['10', '11', '12'],
          'Natural Sciences': ['7', '8', '9'],
          'Natural Sciences and Technology': ['4', '5', '6'],
          'Physical Sciences': ['10', '11', '12'],
          'Religion Studies': ['10', '11', '12'],
          'Robotics': [
            'R',
            '1',
            '2',
            '3',
            '4',
            '5',
            '6',
            '7',
            '8',
            '9',
            '10',
            '11',
            '12'
          ],
          'Security Sciences': ['10', '11', '12'],
          'Sepedi': [], // No grades specified, default to empty
        };

        for (var entry in subjectGradeMap.entries) {
          final subjectId = _uuid.v4();
          await txn.insert(
              'subjects',
              Subject(
                id: subjectId,
                name: entry.key,
                gradeIds: entry.value,
              ).toMap());
        }

        print("Seeding Languages");
        await txn.insert(
            'languages', Language(id: _uuid.v4(), name: 'Afrikaans').toMap());
        await txn.insert(
            'languages', Language(id: _uuid.v4(), name: 'English').toMap());
        await txn.insert(
            'languages', Language(id: _uuid.v4(), name: 'isiNdebele').toMap());
        await txn.insert(
            'languages', Language(id: _uuid.v4(), name: 'isiXhosa').toMap());
        await txn.insert(
            'languages', Language(id: _uuid.v4(), name: 'isiZulu').toMap());
        await txn.insert(
            'languages', Language(id: _uuid.v4(), name: 'Sepedi').toMap());
        await txn.insert(
            'languages', Language(id: _uuid.v4(), name: 'Sesotho').toMap());
        await txn.insert(
            'languages', Language(id: _uuid.v4(), name: 'Setswana').toMap());
        await txn.insert(
            'languages', Language(id: _uuid.v4(), name: 'siSwati').toMap());
        await txn.insert(
            'languages', Language(id: _uuid.v4(), name: 'Tshivenda').toMap());
        await txn.insert(
            'languages', Language(id: _uuid.v4(), name: 'Xitsonga').toMap());
        await txn.insert(
            'languages',
            Language(id: _uuid.v4(), name: 'South African Sign Language')
                .toMap());

        // Query after all inserts to ensure data is available
        print("Querying seeded data");
        final mathSubject = await txn
            .query('subjects', where: 'name = ?', whereArgs: ['Mathematics']);
        if (mathSubject.isEmpty)
          throw Exception('Mathematics subject not found');
        final scienceSubject = await txn.query('subjects',
            where: 'name = ?', whereArgs: ['Natural Sciences']);
        if (scienceSubject.isEmpty)
          throw Exception('Natural Sciences subject not found');
        final englishSubject = await txn
            .query('subjects', where: 'name = ?', whereArgs: ['English']);
        if (englishSubject.isEmpty)
          throw Exception('English subject not found');
        final gradeR =
            await txn.query('grades', where: 'number = ?', whereArgs: ['R']);
        if (gradeR.isEmpty) throw Exception('Grade R not found');
        final grade10 =
            await txn.query('grades', where: 'number = ?', whereArgs: ['10']);
        if (grade10.isEmpty) throw Exception('Grade 10 not found');
        final grade11 =
            await txn.query('grades', where: 'number = ?', whereArgs: ['11']);
        if (grade11.isEmpty) throw Exception('Grade 11 not found');
        final englishLang = await txn
            .query('languages', where: 'name = ?', whereArgs: ['English']);
        if (englishLang.isEmpty) throw Exception('English language not found');

        print("Seeding Users");
        await txn.insert(
            'users',
            User(
              id: 'user_1',
              country: 'ZA',
              citizenshipId: '123456789',
              name: 'Ms. Smith',
              surname: '',
              role: 'teacher',
              roleData: {
                'qualifiedSubjects': [
                  {
                    'subjectId': mathSubject.first['id'] as String,
                    'gradeId': grade10.first['id'] as String
                  },
                  {
                    'subjectId': scienceSubject.first['id'] as String,
                    'gradeId': grade10.first['id'] as String
                  },
                ],
                'homeLanguageId': englishLang.first['id'] as String,
                'preferredLanguageId': englishLang.first['id'] as String,
              },
            ).toMap());
        await txn.insert(
            'users',
            User(
              id: 'user_2',
              country: 'ZA',
              citizenshipId: '987654321',
              name: 'Mr. Jones',
              surname: '',
              role: 'teacher',
              roleData: {
                'qualifiedSubjects': [
                  {
                    'subjectId': englishSubject.first['id'] as String,
                    'gradeId': grade11.first['id'] as String
                  },
                ],
                'homeLanguageId': englishLang.first['id'] as String,
                'preferredLanguageId': englishLang.first['id'] as String,
              },
            ).toMap());
        await txn.insert(
            'users',
            User(
              id: 'user_3',
              country: 'ZA',
              citizenshipId: '111111111',
              name: 'Alice',
              surname: '',
              role: 'learner',
              roleData: {
                'selectedGrade': grade10.first['id'] as String,
                'selectedSubjects': [
                  mathSubject.first['id'] as String,
                  scienceSubject.first['id'] as String
                ],
                'homeLanguageId': englishLang.first['id'] as String,
                'preferredLanguageId': englishLang.first['id'] as String,
              },
            ).toMap());
        await txn.insert(
            'users',
            User(
              id: 'user_4',
              country: 'ZA',
              citizenshipId: '222222222',
              name: 'Bob',
              surname: '',
              role: 'learner',
              roleData: {
                'selectedGrade': grade10.first['id'] as String,
                'selectedSubjects': [
                  mathSubject.first['id'] as String,
                  scienceSubject.first['id'] as String
                ],
                'homeLanguageId': englishLang.first['id'] as String,
                'preferredLanguageId': englishLang.first['id'] as String,
              },
            ).toMap());
        await txn.insert(
            'users',
            User(
              id: 'user_5',
              country: 'ZA',
              citizenshipId: '333333333',
              name: 'Charlie',
              surname: '',
              role: 'learner',
              roleData: {
                'selectedGrade': grade11.first['id'] as String,
                'selectedSubjects': [englishSubject.first['id'] as String],
                'homeLanguageId': englishLang.first['id'] as String,
                'preferredLanguageId': englishLang.first['id'] as String,
              },
            ).toMap());
        await txn.insert(
            'users',
            User(
              id: 'user_6',
              country: 'ZA',
              citizenshipId: '444444444',
              name: 'David',
              surname: '',
              role: 'learner',
              roleData: {
                'selectedGrade': grade11.first['id'] as String,
                'selectedSubjects': [englishSubject.first['id'] as String],
                'homeLanguageId': englishLang.first['id'] as String,
                'preferredLanguageId': englishLang.first['id'] as String,
              },
            ).toMap());
        await txn.insert(
            'users',
            User(
              id: 'user_7',
              country: 'ZA',
              citizenshipId: '555555555',
              name: 'Eve',
              surname: '',
              role: 'learner',
              roleData: {
                'selectedGrade':
                    grade10.first['id'] as String, // Updated to grade10
                'selectedSubjects': [mathSubject.first['id'] as String],
                'homeLanguageId': englishLang.first['id'] as String,
                'preferredLanguageId': englishLang.first['id'] as String,
              },
            ).toMap());

        print("Seeding ClassData");
        await txn.insert(
            'classdata',
            ClassData(
              id: 'class_1',
              teacherId: 'user_1',
              subjectId: mathSubject.first['id'] as String,
              gradeId: grade10.first['id'] as String,
              title: 'Mathematics 10 Class 1',
              createdAt: DateTime.now().millisecondsSinceEpoch,
              learnerIds: ['user_3', 'user_4', 'user_7'],
            ).toMap());
        await txn.insert(
            'classdata',
            ClassData(
              id: 'class_2',
              teacherId: 'user_1',
              subjectId: scienceSubject.first['id'] as String,
              gradeId: grade10.first['id'] as String,
              title: 'Natural Sciences 10 Class 1',
              createdAt: DateTime.now().millisecondsSinceEpoch,
              learnerIds: ['user_3', 'user_4', 'user_7'],
            ).toMap());
        await txn.insert(
            'classdata',
            ClassData(
              id: 'class_3',
              teacherId: 'user_2',
              subjectId: englishSubject.first['id'] as String,
              gradeId: grade11.first['id'] as String,
              title: 'English 11 Class 1',
              createdAt: DateTime.now().millisecondsSinceEpoch,
              learnerIds: ['user_5', 'user_6'],
            ).toMap());

        print("Seeding Timetables and TimetableSlots");
        final seedDate = DateTime.now().toIso8601String().split('T')[0];
        final teacher1Timetable = Timetable(
          id: _uuid.v4(),
          teacherId: 'user_1',
          userId: 'user_1',
          userRole: 'teacher',
        );
        await insertTimetable(
            teacher1Timetable,
            [
              {
                'id': _uuid.v4(),
                'classId': 'class_1',
                'timeSlot': '$seedDate 09:00-10:00',
                'learnerIds': ['user_3', 'user_4', 'user_7'],
              },
              {
                'id': _uuid.v4(),
                'classId': 'class_1',
                'timeSlot': '$seedDate 10:00-11:00',
                'learnerIds': ['user_3', 'user_4', 'user_7'],
              },
              {
                'id': _uuid.v4(),
                'classId': 'class_2',
                'timeSlot': '$seedDate 11:00-12:00',
                'learnerIds': ['user_3', 'user_4', 'user_7'],
              },
            ],
            db);

        final teacher2Timetable = Timetable(
          id: _uuid.v4(),
          teacherId: 'user_2',
          userId: 'user_2',
          userRole: 'teacher',
        );
        await insertTimetable(
            teacher2Timetable,
            [
              {
                'id': _uuid.v4(),
                'classId': 'class_3',
                'timeSlot': '$seedDate 13:00-14:00',
                'learnerIds': ['user_5', 'user_6'],
              },
              {
                'id': _uuid.v4(),
                'classId': 'class_3',
                'timeSlot': '$seedDate 14:00-15:00',
                'learnerIds': ['user_5', 'user_6'],
              },
            ],
            db);

        print("Registering Learner Devices");
        await _registerLearnerDevice(
            db, 'user_3', 'device_1', 'user_1', 'class_1');
        await _registerLearnerDevice(
            db, 'user_4', 'device_2', 'user_1', 'class_1');
        await _registerLearnerDevice(
            db, 'user_5', 'device_3', 'user_2', 'class_3');
        await _registerLearnerDevice(
            db, 'user_6', 'device_4', 'user_2', 'class_3');
        await _registerLearnerDevice(
            db, 'user_7', 'device_5', 'user_1', 'class_2');
      }
    });
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    await _db!.update(
      'learner_devices',
      {'last_sync_time': timestamp},
      where: 'learnerId = ?',
      whereArgs: [learnerId],
    );
  }

  Future<void> cacheTeacherDevice(
      String teacherId, String classId, String ip, int port) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
            .query('classdata', where: 'id = ?', whereArgs: [classId]);
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
        final classGradeId =
            classData.isNotEmpty ? classData[0]['gradeId'] as String? : null;
        if (classGradeId == null) return 'Class gradeId is null';
        for (final learnerId in learnerIds) {
          final user = await database.query('users',
              where: 'id = ?', whereArgs: [learnerId], columns: ['roleData']);
          print("User data for $learnerId: $user");
          if (user.isEmpty ||
              (jsonDecode(user[0]['roleData'] as String)['selectedGrade']
                      as String?) !=
                  classGradeId) {
            return 'Learner $learnerId does not match class grade $classGradeId';
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

  Future<void> insertUserData(User user) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      await _db!.insert('users', user.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      await _queueSync(_db!, 'users', 'insert', user.toMap());
    } catch (e) {
      throw Exception('Failed to insert user: $e');
    }
  }

  Future<User?> getUserDataById(String id) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      final maps = await _db!.query(
        'users',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (maps.isEmpty) return null;
      return User.fromMap(maps.first);
    } catch (e) {
      print("Error fetching user data by ID: $e");
      return null;
    }
  }

  Future<void> updateUserData(User user) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      await _db!
          .update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
      await _queueSync(_db!, 'users', 'update', user.toMap());
    } catch (e) {
      print('Error updating user data: $e');
      throw e;
    }
  }

  Future<Map<String, dynamic>?> getUserByCitizenship(
      String country, String citizenshipId) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      print(
          "Querying user for country: $country, citizenshipId: $citizenshipId");
      final maps = await _db!.query(
        'users',
        where: 'country = ? AND citizenshipId = ?',
        whereArgs: [country, citizenshipId],
      );
      print("Query result: $maps");
      if (maps.isEmpty) return null;
      final userMap = maps.first;
      if (userMap['id'] == null || userMap['role'] == null) {
        throw Exception('User data missing required fields (id or role)');
      }
      return userMap;
    } catch (e) {
      print("Error fetching user by citizenship: $e");
      throw Exception('Failed to fetch user by citizenship: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    return await _db!.query('users');
  }

  Future<void> syncDataWithTeacher(String teacherCountry,
      String teacherCitizenshipId, BuildContext context) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      final user =
          await getUserByCitizenship(teacherCountry, teacherCitizenshipId);
      if (user != null && user['role'] == 'teacher') {
        final teacherId = user['id'] as String;
        final learners = await _db!.query(
          'users',
          where: 'country = ? AND role = ?',
          whereArgs: [teacherCountry, 'learner'],
        );
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

  Future<List<Map<String, dynamic>>> getAllTimetableSlots() async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      print("Fetching all timetable slots");
      final maps = await _db!.rawQuery('''
        SELECT ts.id AS slot_id, tsa.timetableId, ts.classId, ts.timeSlot, ts.learnerIds,
               s.name AS subject, g.number AS grade
        FROM timetables t
        JOIN timetable_slot_association tsa ON t.id = tsa.timetableId
        JOIN timetable_slots ts ON tsa.slotId = ts.id
        JOIN classdata c ON ts.classId = c.id
        JOIN subjects s ON c.subjectId = s.id
        JOIN grades g ON c.gradeId = g.id
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

  Future<List<Map<String, dynamic>>> getTeacherTimetableSlots(
      String teacherId) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      print("Fetching timetable slots for teacherId: $teacherId");
      final maps = await _db!.rawQuery('''
      SELECT DISTINCT ts.id AS slot_id, tsa.timetableId, ts.classId, ts.timeSlot, ts.learnerIds,
             s.name AS subject, g.number AS grade
      FROM timetables t
      JOIN timetable_slot_association tsa ON t.id = tsa.timetableId
      JOIN timetable_slots ts ON tsa.slotId = ts.id
      JOIN classdata c ON ts.classId = c.id
      JOIN subjects s ON c.subjectId = s.id
      JOIN grades g ON c.gradeId = g.id
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      print("Fetching timetable slots for learnerId: $learnerId");
      final maps = await _db!.rawQuery('''
      SELECT ts.id AS slot_id, ts.classId, ts.timeSlot, ts.learnerIds,
             s.name AS subject, g.number AS grade
      FROM learner_timetables lt
      JOIN timetable_slots ts ON lt.classId = ts.classId AND lt.timeSlot = ts.timeSlot
      JOIN classdata c ON ts.classId = c.id
      JOIN subjects s ON c.subjectId = s.id
      JOIN grades g ON c.gradeId = g.id
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

  Future<List<Subject>> getAllSubjects() async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      final maps = await _db!.query('subjects');
      print("Raw subjects query result: $maps"); // Debug raw data
      return maps.map((map) => Subject.fromMap(map)).toList();
    } catch (e) {
      print("Error fetching all subjects: $e");
      throw Exception('Failed to fetch all subjects: $e');
    }
  }

  Future<List<Grade>> getAllGrades() async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      final maps = await _db!.query('grades');
      print("Grades query result: $maps"); // Debug log
      return maps
          .map((map) => Grade(
              id: map['id'] as String,
              number: map['number'] as String)) // Changed from int to String
          .toList();
    } catch (e) {
      print("Error fetching all grades: $e");
      throw Exception('Failed to fetch all grades: $e');
    }
  }

  Future<List<Language>> getAllLanguages() async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      final maps = await _db!.query('languages');
      print("Languages query result: $maps"); // Debug log
      return maps
          .map((map) =>
              Language(id: map['id'] as String, name: map['name'] as String))
          .toList();
    } catch (e) {
      print("Error fetching all languages: $e");
      throw Exception('Failed to fetch all languages: $e');
    }
  }

  Future<void> insertClassData(ClassData classData) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      await _db!.insert('classdata', classData.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      print('Error inserting class data: $e');
      throw e;
    }
  }

  Future<ClassData> getClassDataById(String id) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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

  Future<void> updateClassLearnerIds(
      String classId, List<String> learnerIds) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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

      // Check for existing timetable for the user
      final existingTimetable = await database.query('timetables',
          where: 'userId = ? AND userRole = ?',
          whereArgs: [timetableData['userId'], timetableData['userRole']],
          limit: 1);
      if (existingTimetable.isNotEmpty) {
        timetableData['id'] = existingTimetable.first['id'] as String;
      } else {
        timetableData['id'] = _uuid.v4();
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
        }

        // Associate user with slots
        if (slotIds.isNotEmpty) {
          final associationId = _uuid.v4();
          await txn.insert(
              'timetable_slot_association',
              TimetableSlotAssociation(
                      id: associationId,
                      userId: timetableData['userId'],
                      timetableId: timetableData['id'],
                      slotId: slotIds[0])
                  .toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace);
          await _queueSync(
              txn,
              'timetable_slot_association',
              'insert',
              TimetableSlotAssociation(
                      id: associationId,
                      userId: timetableData['userId'],
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
    if (txn == null) {
      throw Exception('Transaction not initialized');
    }
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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

  Future<List<TimetableSlotAssociation>>
      getTimetableSlotAssociationsByTimetableId(String timetableId) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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

  Future<List<TimetableSlot>> getTimetableSlotsByTimetableId(
      String timetableId) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      final maps = await _db!.rawQuery('''
        SELECT ts.*
        FROM timetable_slots ts
        JOIN timetable_slot_association tsa ON ts.id = tsa.slotId
        WHERE tsa.timetableId = ?
      ''', [timetableId]);
      return maps
          .map((map) => TimetableSlot(
                id: map['id'] as String,
                classId: map['classId'] as String,
                timeSlot: map['timeSlot'] as String,
                learnerIds: (map['learnerIds'] as String?)?.split(',') ?? [],
              ))
          .toList();
    } catch (e) {
      print('Error fetching timetable slots for timetableId $timetableId: $e');
      throw Exception('Failed to fetch timetable slots: $e');
    }
  }

  Future<void> insertQuestion(Question question) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      await _db!.transaction((txn) async {
        final classData = await txn
            .query('classdata', where: 'id = ?', whereArgs: [question.classId]);
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      await _db!.transaction((txn) async {
        final questionData = await txn.query('questions',
            where: 'id = ?', whereArgs: [answer.questionId]);
        if (questionData.isEmpty) throw Exception('Invalid question ID');
        final classId = questionData[0]['classId'] as String;
        final classData =
            await txn.query('classdata', where: 'id = ?', whereArgs: [classId]);
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
    if (txn == null) {
      throw Exception('Transaction not initialized');
    }
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      await _db!.delete('sync_pending', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      throw Exception('Failed to clear pending sync: $e');
    }
  }

  Future<void> updateLearnerTimetableStatus(
      String learnerId, String timetableId, String status) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
    if (_db == null) {
      throw Exception('Database not initialized');
    }
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
          strokes: [], // Default to empty list if not found
          assets: assets.map((a) => a.toJson()).toList(),
        ),
      );
      final updatedAnswer = Answer(
        id: answer.id,
        questionId: answer.questionId,
        learnerId: answer.learnerId,
        strokes: answer.strokes,
        assets: assets.map((a) => a.toJson()).toList(),
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

  Future<void> insertAnalytics(Analytics analytics) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      await _db!.transaction((txn) async {
        await txn.insert('analytics', analytics.toJson(),
            conflictAlgorithm: ConflictAlgorithm.replace);
        await _queueSync(txn, 'analytics', 'insert', analytics.toJson());
      });
    } catch (e) {
      throw Exception('Failed to insert analytics: $e');
    }
  }

  Future<List<Analytics>> getAnalyticsByLearner(String learnerId) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      final maps = await _db!
          .query('analytics', where: 'learnerId = ?', whereArgs: [learnerId]);
      return maps.map((map) => Analytics.fromJson(map)).toList();
    } catch (e) {
      throw Exception('Failed to fetch analytics: $e');
    }
  }

  Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      _isInitialized = false;
      print("Database closed at ${DateTime.now()} SAST");
    }
  }

  Future<void> insertTimetableSlotAssociation(
      TimetableSlotAssociation association) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      await _db!.insert(
        'timetable_slot_association',
        {
          'id': association.id,
          'userId': association.userId,
          'timetableId': association.timetableId,
          'slotId': association.slotId,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error inserting timetable slot association: $e');
      throw Exception('Failed to insert timetable slot association: $e');
    }
  }

  Future<void> insertTimetableSlot(TimetableSlot slot) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      await _db!.insert(
        'timetable_slots',
        {
          'id': slot.id,
          'classId': slot.classId,
          'timeSlot': slot.timeSlot,
          'learnerIds': slot.learnerIds.join(','),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error inserting timetable slot: $e');
      throw Exception('Failed to insert timetable slot: $e');
    }
  }

  Future<void> insertData(String tableName, Map<String, dynamic> data,
      {ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.replace}) async {
    if (_db == null) {
      throw Exception('Database not initialized');
    }
    try {
      await _db!.insert(
        tableName,
        data,
        conflictAlgorithm: conflictAlgorithm,
      );
    } catch (e) {
      print('Error inserting data into $tableName: $e');
      throw Exception('Failed to insert data into $tableName: $e');
    }
  }

  Future<Question?> getQuestionById(String id) async {
    try {
      final result = await _db?.query('questions',
          where: 'id = ?', whereArgs: [id], limit: 1);
      return result!.isNotEmpty ? Question.fromMap(result.first) : null;
    } catch (e) {
      print('Error fetching question by ID: $e');
      return null;
    }
  }

  Future<List<Asset>> getAssetsByQuestion(String questionId) async {
    try {
      final result = await _db
          ?.query('assets', where: 'questionId = ?', whereArgs: [questionId]);
      if (result == null) return [];
      return result.map((map) => Asset.fromMap(map)).toList();
    } catch (e) {
      print('Error fetching assets by question: $e');
      return [];
    }
  }

  Future<void> updateQuestion(Question question) async {
    try {
      await _db?.update(
        'questions',
        question.toMap(),
        where: 'id = ?',
        whereArgs: [question.id],
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      print('Error updating question: $e');
    }
  }
}
