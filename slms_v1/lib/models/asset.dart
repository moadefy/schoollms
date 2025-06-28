import 'package:sqflite/sqflite.dart';

class Asset {
  final String id; // Unique identifier
  final String learnerId; // Reference to the learner
  final String? questionId; // Reference to the question (optional)
  final String type; // e.g., 'image' or 'pdf'
  final String data; // Base64-encoded data or path
  final double positionX; // X-coordinate position
  final double positionY; // Y-coordinate position
  final double scale; // Scaling factor
  final int created_at; // Timestamp of creation

  Asset({
    required this.id,
    required this.learnerId,
    this.questionId,
    required this.type,
    required this.data,
    this.positionX = 0.0,
    this.positionY = 0.0,
    this.scale = 1.0,
    required this.created_at,
  });

  factory Asset.fromJson(Map<String, dynamic> json) {
    return Asset(
      id: json['id'] as String,
      learnerId: json['learnerId'] as String,
      questionId: json['questionId'] as String?,
      type: json['type'] as String,
      data: json['data'] as String,
      positionX: (json['positionX'] as num?)?.toDouble() ?? 0.0,
      positionY: (json['positionY'] as num?)?.toDouble() ?? 0.0,
      scale: (json['scale'] as num?)?.toDouble() ?? 1.0,
      created_at: json['created_at'] as int,
    );
  }

  factory Asset.fromMap(Map<String, dynamic> map) {
    return Asset(
      id: map['id'] as String,
      learnerId: map['learnerId'] as String,
      questionId: map['questionId'] as String?,
      type: map['type'] as String,
      data: map['data'] as String,
      positionX: (map['positionX'] as num?)?.toDouble() ?? 0.0,
      positionY: (map['positionY'] as num?)?.toDouble() ?? 0.0,
      scale: (map['scale'] as num?)?.toDouble() ?? 1.0,
      created_at: map['created_at'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'learnerId': learnerId,
      'questionId': questionId,
      'type': type,
      'data': data,
      'positionX': positionX,
      'positionY': positionY,
      'scale': scale,
      'created_at': created_at,
    };
  }

  // Add this if using SQLite with sqflite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'learnerId': learnerId,
      'questionId': questionId,
      'type': type,
      'data': data,
      'positionX': positionX,
      'positionY': positionY,
      'scale': scale,
      'created_at': created_at,
    };
  }

  static Future<void> createTable(Database db) async {
    await db.execute('''
      CREATE TABLE assets (
        id TEXT PRIMARY KEY,
        learnerId TEXT NOT NULL,
        questionId TEXT,
        type TEXT NOT NULL,
        data TEXT NOT NULL,
        positionX REAL NOT NULL,
        positionY REAL NOT NULL,
        scale REAL NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }
}
