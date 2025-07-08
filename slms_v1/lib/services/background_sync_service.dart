import 'dart:async';
import 'package:flutter/material.dart'; // For BuildContext and TimeOfDay
import 'package:provider/provider.dart'; // For Provider
import 'package:intl/intl.dart'; // For TimeOfDay formatting
import 'package:schoollms/services/database_service.dart';
import 'package:schoollms/services/sync_service.dart';
import 'package:schoollms/services/connection_service.dart'; // Added for connectLearner
import 'package:schoollms/providers/sync_state.dart';
import 'package:schoollms/models/learnertimetable.dart'; // Import for LearnerTimetable

class BackgroundSyncService {
  final DatabaseService _dbService;
  final SyncService _syncService;
  final ConnectionService _connectionService; // Added for learner connections
  Timer? _syncTimer;

  BackgroundSyncService(
      this._dbService, this._syncService, this._connectionService);

  void startBackgroundSync(String userId, BuildContext context,
      {bool isTeacher = false}) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      try {
        final now = DateTime.now();
        if (isTeacher) {
          // Sync teacher changes to learners
          final learners = await _dbService.getAllLearnersForTeacher(userId);
          for (var learner in learners) {
            await _syncTeacherToLearner(userId, learner, context, now);
          }
        } else {
          // Sync learner changes to teacher/parent
          final timetables = await _dbService.getLearnerTimetable(userId);
          for (var timetable in timetables) {
            if (timetable.timeSlot != null && timetable.timeSlot.isNotEmpty) {
              final timeSlot = timetable.timeSlot.split(' ')[1].split('-');
              if (timeSlot.length == 2) {
                final startTime = _parseTime(timeSlot[0], now);
                final endTime = _parseTime(timeSlot[1], now);
                if (now.isAfter(startTime) && now.isBefore(endTime)) {
                  final classData =
                      await _dbService.getClassDataById(timetable.classId);
                  if (classData != null && classData.teacherId != null) {
                    final teacherId = classData.teacherId;
                    await _connectionService.connectLearner(
                        teacherId, timetable.classId, userId);
                    await _syncLearnerToRemote(userId, teacherId, context, now);
                    Provider.of<SyncState>(context, listen: false)
                        .updateSyncStatus(
                            lastSyncTime:
                                TimeOfDay.fromDateTime(now).format(context));
                  }
                }
              }
            }
          }
        }
      } catch (e) {
        Provider.of<SyncState>(context, listen: false)
            .updateSyncStatus(error: 'Sync failed: $e');
      }
    });
  }

  Future<void> _syncTeacherToLearner(String teacherId, String learnerId,
      BuildContext context, DateTime now) async {
    try {
      // Get changes in teacher database/files for this learner
      final teacherChanges =
          await _dbService.getPendingTeacherChanges(teacherId, learnerId);
      if (teacherChanges.isNotEmpty) {
        await _connectionService.connectLearner(
            teacherId, learnerId, learnerId); // Connect to learner
        await _syncService.startSyncing(
            teacherId, learnerId); // Sync changes to learner
        await _dbService.clearPendingTeacherChanges(
            teacherId, learnerId); // Clear after sync
        Provider.of<SyncState>(context, listen: false).updateSyncStatus(
            lastSyncTime: TimeOfDay.fromDateTime(now).format(context));
      }
    } catch (e) {
      Provider.of<SyncState>(context, listen: false)
          .updateSyncStatus(error: 'Teacher sync failed: $e');
    }
  }

  Future<void> _syncLearnerToRemote(String learnerId, String teacherId,
      BuildContext context, DateTime now) async {
    try {
      // Get changes in learner database/files on teacher device
      final learnerChanges =
          await _dbService.getPendingLearnerChanges(learnerId, teacherId);
      if (learnerChanges.isNotEmpty) {
        await _syncService.startSyncing(
            teacherId, learnerId); // Sync to teacher
        await _dbService.clearPendingLearnerChanges(
            learnerId, teacherId); // Clear after sync
        Provider.of<SyncState>(context, listen: false).updateSyncStatus(
            lastSyncTime: TimeOfDay.fromDateTime(now).format(context));
      }
    } catch (e) {
      Provider.of<SyncState>(context, listen: false)
          .updateSyncStatus(error: 'Learner sync failed: $e');
    }
  }

  DateTime _parseTime(String time, DateTime date) {
    final parts = time.split(':');
    return DateTime(
      date.year,
      date.month,
      date.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  void stopBackgroundSync() {
    _syncTimer?.cancel();
  }
}
