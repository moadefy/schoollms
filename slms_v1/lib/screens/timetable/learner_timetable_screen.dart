import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../providers/sync_state.dart';
import '../../models/learner_timetable.dart';
import '../../models/timetable.dart';

class LearnerTimetableScreen extends StatefulWidget {
  final String learnerId;

  const LearnerTimetableScreen({Key? key, required this.learnerId})
      : super(key: key);

  @override
  State<LearnerTimetableScreen> createState() => _LearnerTimetableScreenState();
}

class _LearnerTimetableScreenState extends State<LearnerTimetableScreen> {
  List<Timetable> _timetables = [];

  @override
  void initState() {
    super.initState();
    _loadTimetables();
  }

  Future<void> _loadTimetables() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final learnerTimetables =
        await dbService.getLearnerTimetables(widget.learnerId);
    final timetableIds = learnerTimetables.map((lt) => lt.timetableId).toSet();
    final timetables = <Timetable>[];
    for (final id in timetableIds) {
      final timetable = await dbService.getTimetableById(id);
      if (timetable != null) {
        timetables.add(timetable);
      }
    }
    setState(() {
      _timetables = timetables;
    });
  }

  @override
  Widget build(BuildContext context) {
    final syncState = Provider.of<SyncState>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Learner Timetable')),
      body: Column(
        children: [
          // Sync status
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last Sync: ${syncState.lastSyncTime != null ? syncState.lastSyncTime!.toString() : "Never"}',
                ),
                if (syncState.lastError != null)
                  Text(
                    'Sync Error: ${syncState.lastError}',
                    style: const TextStyle(color: Colors.red),
                  ),
              ],
            ),
          ),
          // Timetable list
          Expanded(
            child: _timetables.isEmpty
                ? const Center(child: Text('No timetable available'))
                : ListView.builder(
                    itemCount: _timetables.length,
                    itemBuilder: (context, index) {
                      final timetable = _timetables[index];
                      return ListTile(
                        title: Text(timetable.subject),
                        subtitle: Text(
                            '${timetable.day} ${timetable.startTime}-${timetable.endTime}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
