import 'package:sqflite/sqflite.dart';
import 'dart:convert';

class TeacherData {
  final String id;
  final String country;
  final String citizenshipId;
  final String name;
  final String surname;
  final String homeLanguage;
  final String preferredLanguage;
  final Map<String, List<String>>
      qualifiedSubjects; // Grade -> List of subjects
  final List<String> supportingDocuments; // URLs or paths to documents
  String? timetableId; // Links to a Timetable, which contains TimetableSlots

  TeacherData({
    required this.id,
    required this.country,
    required this.citizenshipId,
    required this.name,
    required this.surname,
    required this.homeLanguage,
    required this.preferredLanguage,
    required this.qualifiedSubjects,
    required this.supportingDocuments,
    this.timetableId,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'country': country,
      'citizenshipId': citizenshipId,
      'name': name,
      'surname': surname,
      'homeLanguage': homeLanguage,
      'preferredLanguage': preferredLanguage,
      'qualifiedSubjects': jsonEncode(qualifiedSubjects),
      'supportingDocuments': jsonEncode(supportingDocuments),
      'timetableId': timetableId,
    };
  }

  factory TeacherData.fromMap(Map<String, dynamic> map) {
    return TeacherData(
      id: map['id'] as String,
      country: map['country'] as String,
      citizenshipId: map['citizenshipId'] as String,
      name: map['name'] as String,
      surname: map['surname'] as String,
      homeLanguage: map['homeLanguage'] as String,
      preferredLanguage: map['preferredLanguage'] as String,
      qualifiedSubjects: map['qualifiedSubjects'] != null
          ? Map<String, List<String>>.from(
              jsonDecode(map['qualifiedSubjects'] as String)
                  .map((k, v) => MapEntry(k as String, List<String>.from(v))))
          : {},
      supportingDocuments: map['supportingDocuments'] != null
          ? List<String>.from(jsonDecode(map['supportingDocuments'] as String))
          : [],
      timetableId: map['timetableId'] as String?,
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE teacherdata (
        id TEXT PRIMARY KEY,
        country TEXT NOT NULL,
        citizenshipId TEXT NOT NULL,
        name TEXT NOT NULL,
        surname TEXT NOT NULL,
        homeLanguage TEXT NOT NULL,
        preferredLanguage TEXT NOT NULL,
        qualifiedSubjects TEXT NOT NULL,
        supportingDocuments TEXT NOT NULL,
        timetableId TEXT,
        FOREIGN KEY (timetableId) REFERENCES timetables(id) ON DELETE SET NULL
      )
    ''');
  }

  // Optional: Method to fetch associated TimetableSlots (to be implemented in service)
  // This will be handled in DatabaseService later
}
