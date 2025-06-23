import 'package:sqflite/sqflite.dart';

class User {
  final String id;
  final String country;
  final String citizenshipId;
  final String name;
  final String surname;
  final String email;
  final String contactNumber;

  User(
      {required this.id,
      required this.country,
      required this.citizenshipId,
      required this.name,
      required this.surname,
      this.email = '',
      this.contactNumber = ''});

  Map<String, dynamic> toMap() => {
        'id': id,
        'country': country,
        'citizenshipId': citizenshipId,
        'name': name,
        'surname': surname,
        'email': email,
        'contactNumber': contactNumber,
      };

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
        UNIQUE (country, citizenshipId) -- Ensure unique citizenship per country
      )
    ''');
  }
}
