import 'package:sqflite/sqflite.dart';
import 'dart:convert';

class LearnerData {
  final String id;
  final String country;
  final String citizenshipId;
  final String name;
  final String surname;
  final String homeLanguage;
  final String preferredLanguage;
  final String grade;
  final List<String> subjects;
  final ParentDetails parentDetails;
  String?
      timetableId; // Can link to a unique learner timetable or slot aggregation

  LearnerData({
    required this.id,
    required this.country,
    required this.citizenshipId,
    required this.name,
    required this.surname,
    required this.homeLanguage,
    required this.preferredLanguage,
    required this.grade,
    required this.subjects,
    required this.parentDetails,
    this.timetableId,
    String? classId,
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
      'grade': grade,
      'subjects': jsonEncode(subjects),
      'parentDetails': jsonEncode(parentDetails.toMap()),
      'timetableId': timetableId,
    };
  }

  factory LearnerData.fromMap(Map<String, dynamic> map) {
    return LearnerData(
      id: map['id'] as String,
      country: map['country'] as String,
      citizenshipId: map['citizenshipId'] as String,
      name: map['name'] as String,
      surname: map['surname'] as String,
      homeLanguage: map['homeLanguage'] as String,
      preferredLanguage: map['preferredLanguage'] as String,
      grade: map['grade'] as String,
      subjects: map['subjects'] != null
          ? List<String>.from(jsonDecode(map['subjects'] as String))
          : [],
      parentDetails:
          ParentDetails.fromMap(jsonDecode(map['parentDetails'] as String)),
      timetableId: map['timetableId'] as String?,
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE learnerdata (
        id TEXT PRIMARY KEY,
        country TEXT NOT NULL,
        citizenshipId TEXT NOT NULL,
        name TEXT NOT NULL,
        surname TEXT NOT NULL,
        homeLanguage TEXT NOT NULL,
        preferredLanguage TEXT NOT NULL,
        grade TEXT NOT NULL,
        subjects TEXT NOT NULL,
        parentDetails TEXT NOT NULL,
        timetableId TEXT,
        FOREIGN KEY (timetableId) REFERENCES timetables(id) ON DELETE SET NULL
      )
    ''');
  }

  // Added copyWith method
  LearnerData copyWith({
    String? id,
    String? country,
    String? citizenshipId,
    String? name,
    String? surname,
    String? homeLanguage,
    String? preferredLanguage,
    String? grade,
    List<String>? subjects,
    ParentDetails? parentDetails,
    String? timetableId,
  }) {
    return LearnerData(
      id: id ?? this.id,
      country: country ?? this.country,
      citizenshipId: citizenshipId ?? this.citizenshipId,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      homeLanguage: homeLanguage ?? this.homeLanguage,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      grade: grade ?? this.grade,
      subjects: subjects ?? this.subjects,
      parentDetails: parentDetails ?? this.parentDetails,
      timetableId: timetableId ?? this.timetableId,
    );
  }
}

class ParentDetails {
  final String id;
  final String name;
  final String surname;
  final String email;
  final String contactNumber;
  final String occupation;

  ParentDetails({
    required this.id,
    required this.name,
    required this.surname,
    required this.email,
    required this.contactNumber,
    required this.occupation,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'surname': surname,
      'email': email,
      'contactNumber': contactNumber,
      'occupation': occupation,
    };
  }

  factory ParentDetails.fromMap(Map<String, dynamic> map) {
    return ParentDetails(
      id: map['id'] as String,
      name: map['name'] as String,
      surname: map['surname'] as String,
      email: map['email'] as String,
      contactNumber: map['contactNumber'] as String,
      occupation: map['occupation'] as String,
    );
  }

  // Added copyWith for ParentDetails (optional, but useful for updates)
  ParentDetails copyWith({
    String? id,
    String? name,
    String? surname,
    String? email,
    String? contactNumber,
    String? occupation,
  }) {
    return ParentDetails(
      id: id ?? this.id,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      email: email ?? this.email,
      contactNumber: contactNumber ?? this.contactNumber,
      occupation: occupation ?? this.occupation,
    );
  }
}
