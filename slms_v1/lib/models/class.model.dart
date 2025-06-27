import 'package:sqflite/sqflite.dart';
import 'dart:convert';

class ClassData {
  final String id;
  final String teacherId;
  final String subjectId; // Changed from subject to subjectId
  final String gradeId; // Changed from grade to gradeId
  final String title; // Auto-generated, e.g., "Math 10 Class 1"
  final int createdAt; // Timestamp in milliseconds
  final List<String>
      learnerIds; // List of learner IDs associated with this class

  ClassData({
    required this.id,
    required this.teacherId,
    required this.subjectId,
    required this.gradeId,
    required this.title,
    required this.createdAt,
    this.learnerIds = const [], // Default to empty list
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'subjectId': subjectId,
      'gradeId': gradeId,
      'title': title,
      'createdAt': createdAt,
      'learnerIds': jsonEncode(learnerIds), // Store as JSON string
    };
  }

  factory ClassData.fromMap(Map<String, dynamic> map) {
    return ClassData(
      id: map['id'] as String,
      teacherId: map['teacherId'] as String,
      subjectId: map['subjectId'] as String,
      gradeId: map['gradeId'] as String,
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
        subjectId TEXT NOT NULL,
        gradeId TEXT NOT NULL,
        title TEXT NOT NULL,
        createdAt INTEGER NOT NULL,
        learnerIds TEXT NOT NULL,
        UNIQUE (teacherId, subjectId, gradeId),
        FOREIGN KEY (teacherId) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (subjectId) REFERENCES subjects(id) ON DELETE RESTRICT,
        FOREIGN KEY (gradeId) REFERENCES grades(id) ON DELETE RESTRICT
      )
    ''');
  }

  // Added copyWith method
  ClassData copyWith({
    String? id,
    String? teacherId,
    String? subjectId,
    String? gradeId,
    String? title,
    int? createdAt,
    List<String>? learnerIds,
  }) {
    return ClassData(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      subjectId: subjectId ?? this.subjectId,
      gradeId: gradeId ?? this.gradeId,
      title: title ?? this.title,
      createdAt: createdAt ?? this.createdAt,
      learnerIds: learnerIds ?? this.learnerIds,
    );
  }
}
