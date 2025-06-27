import 'dart:async';
import 'package:flutter/material.dart'; // For BuildContext and TimeOfDay
import 'package:provider/provider.dart'; // For Provider
import 'package:intl/intl.dart'; // For TimeOfDay formatting
import 'package:schoollms/services/database_service.dart';
import 'package:schoollms/services/sync_service.dart';
import 'package:schoollms/providers/sync_state.dart';
import 'package:schoollms/models/learnertimetable.dart'; // Import for LearnerTimetable

class BackgroundSyncService {
  final DatabaseService _dbService;
  final SyncService _syncService;
  Timer? _syncTimer;

  BackgroundSyncService(this._dbService, this._syncService);

  void startBackgroundSync(String learnerId, BuildContext context) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (timer) async {
      try {
        final timetables = await _dbService.getLearnerTimetable(learnerId);
        final now = DateTime.now();
        for (var timetable in timetables) {
          // Ensure timetable has a valid timeSlot
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
                  await _syncService.connectLearner(
                      teacherId, timetable.classId, learnerId);
                  Provider.of<SyncState>(context, listen: false)
                      .updateSyncStatus(
                    lastSyncTime: TimeOfDay.fromDateTime(now).format(context),
                  );
                }
              }
            }
          }
        }
      } catch (e) {
        Provider.of<SyncState>(context, listen: false).updateSyncStatus(
          error: 'Sync failed: $e',
        );
      }
    });
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
