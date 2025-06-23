// class.model.dart
import 'package:sqflite/sqflite.dart';
import 'dart:convert';

class ClassData {
  final String id;
  final String teacherId;
  final String subject;
  final String grade;
  final String title; // Auto-generated, e.g., "Math 10 Class 1"
  final int createdAt; // Timestamp in milliseconds
  final List<String>
      learnerIds; // List of learner IDs associated with this class

  ClassData({
    required this.id,
    required this.teacherId,
    required this.subject,
    required this.grade,
    required this.title,
    required this.createdAt,
    this.learnerIds = const [], // Default to empty list
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'subject': subject,
      'grade': grade,
      'title': title,
      'createdAt': createdAt,
      'learnerIds': jsonEncode(learnerIds), // Store as JSON string
    };
  }

  factory ClassData.fromMap(Map<String, dynamic> map) {
    return ClassData(
      id: map['id'] as String,
      teacherId: map['teacherId'] as String,
      subject: map['subject'] as String,
      grade: map['grade'] as String,
      title: map['title'] as String,
      createdAt: map['createdAt'] as int,
      learnerIds: map['learnerIds'] != null
          ? List<String>.from(jsonDecode(map['learnerIds'] as String))
          : [],
    );
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE classdata (
        id TEXT PRIMARY KEY,
        teacherId TEXT NOT NULL,
        subject TEXT NOT NULL,
        grade TEXT NOT NULL,
        title TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        learnerIds TEXT NOT NULL,
        UNIQUE (teacherId, subject, grade),
        FOREIGN KEY (teacherId) REFERENCES teachers(id) ON DELETE CASCADE
      )
    ''');
  }

  // Added copyWith method
  ClassData copyWith({
    String? id,
    String? teacherId,
    String? subject,
    String? grade,
    String? title,
    int? createdAt,
    List<String>? learnerIds,
  }) {
    return ClassData(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      subject: subject ?? this.subject,
      grade: grade ?? this.grade,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      learnerIds: learnerIds ?? this.learnerIds,
    );
  }
}
