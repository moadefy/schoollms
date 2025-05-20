import 'dart:async';
import 'package:provider/provider.dart';
import 'package:school_app/services/database_service.dart';
import 'package:school_app/services/sync_service.dart';
import 'package:school_app/providers/sync_state.dart';

class BackgroundSyncService {
  final DatabaseService _dbService;
  final SyncService _syncService;
  Timer? _syncTimer;

  BackgroundSyncService(this._dbService, this._syncService);

  void startBackgroundSync(String learnerId, BuildContext context) {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(Duration(minutes: 5), (timer) async {
      try {
        final timetables = await _dbService.getLearnerTimetable(learnerId);
        final now = DateTime.now();
        for (var timetable in timetables) {
          final timeSlot = timetable.timeSlot.split(' ')[1].split('-');
          final startTime = _parseTime(timeSlot[0], now);
          final endTime = _parseTime(timeSlot[1], now);
          if (now.isAfter(startTime) && now.isBefore(endTime)) {
            final classData = await _dbService._db.query('classes',
                where: 'id = ?', whereArgs: [timetable.classId]);
            if (classData.isNotEmpty) {
              final teacherId = classData[0]['teacherId'];
              await _syncService.connectLearner(
                  teacherId, timetable.classId, learnerId);
              Provider.of<SyncState>(context, listen: false).updateSyncStatus(
                lastSyncTime: TimeOfDay.fromDateTime(now).format(context),
              );
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
