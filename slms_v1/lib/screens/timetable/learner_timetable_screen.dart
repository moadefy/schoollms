import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:school_app/services/database_service.dart';
import 'package:school_app/providers/sync_state.dart';
import 'models.dart';

class LearnerTimetableScreen extends StatelessWidget {
  final String learnerId;

  LearnerTimetableScreen({this.learnerId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Learner Timetable')),
      body: Column(
        children: [
          Consumer<SyncState>(
            builder: (context, syncState, child) => Padding(
              padding: EdgeInsets.all(8.0),
              child: Column(
                children: [
                  Text(
                    syncState.lastSyncTime != null
                        ? 'Last synced: ${syncState.lastSyncTime}'
                        : 'Not synced yet',
                    style: TextStyle(fontSize: 16),
                  ),
                  if (syncState.lastError != null)
                    Text(
                      'Error: ${syncState.lastError}',
                      style: TextStyle(color: Colors.red),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<LearnerTimetable>>(
              future: Provider.of<DatabaseService>(context)
                  .getLearnerTimetable(learnerId),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return Center(child: CircularProgressIndicator());
                return ListView.builder(
                  itemCount: snapshot.data.length,
                  itemBuilder: (context, index) {
                    final timetable = snapshot.data[index];
                    return ListTile(
                      title: Text(timetable.timeSlot),
                      subtitle: FutureBuilder<Map<String, dynamic>>(
                        future: Provider.of<DatabaseService>(context)
                            ._db
                            .query('classes', where: 'id = ?', whereArgs: [
                          timetable.classId
                        ]).then((maps) => maps.isNotEmpty ? maps[0] : {}),
                        builder: (context, classSnapshot) {
                          if (!classSnapshot.hasData) return Text('Loading...');
                          return Text(
                              '${classSnapshot.data['subject']} (Grade ${classSnapshot.data['grade']})');
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
