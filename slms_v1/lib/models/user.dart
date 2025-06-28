import 'package:sqflite/sqflite.dart';
import 'dart:convert';

class User {
  final String id;
  final String country;
  final String citizenshipId;
  final String name;
  final String surname;
  final String email;
  final String contactNumber;
  final String role; // From previous update
  final Map<String, dynamic> roleData; // New field for role-specific data

  User({
    required this.id,
    required this.country,
    required this.citizenshipId,
    required this.name,
    required this.surname,
    this.email = '',
    this.contactNumber = '',
    this.role = 'teacher', // Default role from previous update
    this.roleData = const {}, // Default empty map for roleData
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'country': country,
        'citizenshipId': citizenshipId,
        'name': name,
        'surname': surname,
        'email': email,
        'contactNumber': contactNumber,
        'role': role,
        'roleData': jsonEncode(roleData), // Encode roleData as JSON
      };

  User copyWith({
    String? id,
    String? country,
    String? citizenshipId,
    String? name,
    String? surname,
    String? email,
    String? contactNumber,
    String? role,
    Map<String, dynamic>? roleData,
  }) {
    return User(
      id: id ?? this.id,
      country: country ?? this.country,
      citizenshipId: citizenshipId ?? this.citizenshipId,
      name: name ?? this.name,
      surname: surname ?? this.surname,
      email: email ?? this.email,
      contactNumber: contactNumber ?? this.contactNumber,
      role: role ?? this.role,
      roleData: roleData ?? Map<String, dynamic>.from(this.roleData),
    );
  }

  static User fromMap(Map<String, dynamic> map) {
    final roleDataJson = map['roleData'] != null
        ? jsonDecode(map['roleData'] as String) as Map<String, dynamic>
        : {};
    // Correctly deserialize qualifiedSubjects as a List<Map<String, String>>
    final qualifiedSubjects = roleDataJson['qualifiedSubjects'] != null
        ? (roleDataJson['qualifiedSubjects'] as List<dynamic>)
            .map((item) => item as Map<String, dynamic>)
            .map((item) => {
                  'subjectId': item['subjectId'] as String? ?? '',
                  'gradeId': item['gradeId'] as String? ?? '',
                })
            .toList()
        : <Map<String, String>>[];
    return User(
      id: map['id'] as String,
      country: map['country'] as String,
      citizenshipId: map['citizenshipId'] as String,
      name: map['name'] as String,
      surname: map['surname'] as String,
      email: map['email'] as String? ?? '',
      contactNumber: map['contactNumber'] as String? ?? '',
      role: map['role'] as String,
      roleData: {
        ...roleDataJson,
        'qualifiedSubjects': qualifiedSubjects,
      },
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        country TEXT NOT NULL,
        citizenshipId TEXT NOT NULL,
        name TEXT NOT NULL,
        surname TEXT NOT NULL,
        email TEXT,
        contactNumber TEXT,
        role TEXT NOT NULL,
        roleData TEXT, -- New column for role-specific data
        UNIQUE (country, citizenshipId) -- Ensure unique citizenship per country
      )
    ''');
  }
}
