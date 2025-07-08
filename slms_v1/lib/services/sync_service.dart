import 'dart:convert';
import 'dart:io';
import 'dart:math'; // Added for min
import 'package:archive/archive.dart';
import 'package:sqflite/sqflite.dart'; // Added for ConflictAlgorithm
import 'package:schoollms/services/connection_service.dart';
import 'package:schoollms/services/database_service.dart';
import 'package:schoollms/utils/crypto_utils.dart';
import 'package:schoollms/widgets/canvas_widget.dart'; // Import for Stroke
import 'package:schoollms/models/learnertimetable.dart'; // Import for LearnerTimetable
import 'package:schoollms/models/question.dart'; // Import for Question
import 'package:schoollms/models/answer.dart'; // Import for Answer
import 'package:schoollms/models/assessment.dart'; // Added for Assessment
import 'package:schoollms/models/timetable_slot_association.dart'; // Added for TimetableSlotAssociation
import 'package:schoollms/models/timetable_slot.dart'; // Added for TimetableSlot

class SyncService {
  final ConnectionService _connectionService;
  final DatabaseService _dbService;
  static const int chunkSize = 1024 * 512; // 512KB

  SyncService(this._connectionService, this._dbService);

  Future<void> startSyncing(String teacherId, String classId) async {
    await _connectionService.startTeacherConnection(teacherId, classId);
    _monitorConnections(teacherId, classId);
  }

  void _monitorConnections(String teacherId, String classId) {
    // Periodically check connection status and trigger sync
    Future.doWhile(() async {
      if (_connectionService.hasActiveConnections) {
        for (final client in _connectionService.activeConnections) {
          final learnerId = _connectionService.extractLearnerId(client);
          await _processSync(client, learnerId, teacherId, classId);
        }
      }
      await Future.delayed(Duration(milliseconds: 100)); // Check every 100ms
      return true; // Continue monitoring
    });
  }

  Future<void> _processSync(
      Socket client, String learnerId, String teacherId, String classId) async {
    try {
      final deviceData = await _dbService.getLearnerDevice(learnerId);
      final psk = deviceData['psk'] ??
          CryptoUtils.generatePSK(learnerId, teacherId, classId);
      final lastSyncTime = deviceData['last_sync_time'] ?? 0;

      await _processSyncRequest(client, learnerId, psk, lastSyncTime);
      await _dbService.updateLastSyncTime(
          learnerId, DateTime.now().millisecondsSinceEpoch);
      client.write(utf8.encode(jsonEncode({'status': 'synced'})));
    } catch (e) {
      client.write(utf8
          .encode(jsonEncode({'status': 'error', 'message': e.toString()})));
    } finally {
      client.close();
    }
  }

  Future<void> _processSyncRequest(
      Socket client, String learnerId, String psk, int lastSyncTime) async {
    final pendingSyncs =
        await _dbService.getPendingSyncs(sinceTimestamp: lastSyncTime);
    final learnerTimetables = await _dbService.getLearnerTimetable(learnerId,
        sinceTimestamp: lastSyncTime);
    final timetable =
        learnerTimetables.isNotEmpty ? learnerTimetables.first : null;
    final classId = timetable?.classId ?? '';
    final slotAssociations = classId.isNotEmpty
        ? await _dbService
            .getTimetableSlotAssociationsByTimetableId(timetable!.id)
        : [];
    final slots = classId.isNotEmpty
        ? await _dbService.getTimetableSlotsByTimetableId(timetable!.id)
        : [];
    final questions =
        classId.isNotEmpty ? await _dbService.getQuestionsByClass(classId) : [];
    final assessments = classId.isNotEmpty
        ? await _dbService.getAssessmentsByClass(classId)
        : [];

    final batchedSyncs = <String, List<Map<String, dynamic>>>{};
    for (var sync in pendingSyncs) {
      final key = '${sync['table_name']}_${sync['operation']}';
      batchedSyncs[key] ??= [];
      batchedSyncs[key]!.add(sync);
    }

    final canvasData = {
      'strokes': questions.expand((q) {
        final json = jsonDecode(q.content);
        return (json['strokes'] as List)
            .map((s) => Stroke.fromJson(s as Map<String, dynamic>).toProto())
            .where((s) => s.points?.isNotEmpty ?? false);
      }).toList(),
      'assets': questions.expand((q) {
        final json = jsonDecode(q.content);
        return (json['assets'] as List).map((a) => {
              'id': a['id'],
              'type': a['type'],
              'data': a['data'],
              'position': {'x': a['position']['x'], 'y': a['position']['y']},
              'pageIndex': a['pageIndex'],
            });
      }).toList(),
      'lastSyncTime': lastSyncTime,
    };

    final syncData = {
      'timetables': learnerTimetables.map((t) => t.toMap()).toList(),
      'slot_associations': slotAssociations.map((sa) => sa.toMap()).toList(),
      'slots': slots.map((s) => s.toMap()).toList(),
      'questions': questions.map((q) => q.toMap()).toList(),
      'assessments': assessments.map((a) => a.toMap()).toList(),
      'batched_pending': batchedSyncs,
      'canvas_data': canvasData,
    };
    final jsonData = jsonEncode(syncData);
    final compressed = GZipEncoder().encode(utf8.encode(jsonData))!;

    for (int i = 0; i < compressed.length; i += chunkSize) {
      final chunk = compressed.sublist(
          i, min(i + chunkSize, compressed.length)); // Fixed with dart:math
      final encrypted = CryptoUtils.encryptData(utf8.decode(chunk), psk);
      client.write(utf8.encode(encrypted));
    }

    for (var sync in pendingSyncs) {
      await _dbService.clearPendingSync(sync['id']);
    }
  }

  void _processSyncResponse(Map<String, dynamic> response) {
    final timetables = response['timetables'] as List;
    final slotAssociations = response['slot_associations'] as List;
    final slots = response['slots'] as List;
    final questions = response['questions'] as List;
    final assessments = response['assessments'] as List;
    final answers = response['answers'] as List? ?? [];
    final batchedPending = response['batched_pending'] as Map<String, dynamic>;

    for (var t in timetables) {
      _dbService.insertLearnerTimetable(LearnerTimetable.fromMap(t));
    }

    for (var sa in slotAssociations) {
      _dbService
          .insertTimetableSlotAssociation(TimetableSlotAssociation.fromMap(sa));
    }

    for (var s in slots) {
      _dbService.insertTimetableSlot(TimetableSlot.fromMap(s));
    }

    for (var q in questions) {
      _dbService.insertQuestion(Question.fromMap(q));
    }

    for (var a in assessments) {
      _dbService.insertAssessment(Assessment.fromMap(a));
    }

    for (var a in answers) {
      _dbService.insertAnswer(Answer.fromMap(a));
    }

    batchedPending.forEach((key, batch) {
      for (var item in batch) {
        final data = item['data'];
        _dbService.insertData(item['table_name'], data,
            conflictAlgorithm: ConflictAlgorithm.replace); // Fixed with sqflite
      }
    });
  }

  Future<void> stopSyncing() async {
    await _connectionService.stopConnection();
  }
}
