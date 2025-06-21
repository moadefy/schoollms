import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schoollms/services/database_service.dart';
import 'package:schoollms/providers/sync_state.dart';
import 'package:schoollms/models/learnertimetable.dart'; // Ensure this model is defined

class LearnerTimetableScreen extends StatelessWidget {
  final String learnerId;

  LearnerTimetableScreen({required this.learnerId});

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
              future: Provider.of<DatabaseService>(context, listen: false)
                  .getLearnerTimetable(learnerId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(child: Text('No timetable data available'));
                }
                return ListView.builder(
                  itemCount: snapshot.data!.length,
                  itemBuilder: (context, index) {
                    final timetable = snapshot.data![index];
                    return FutureBuilder<Map<String, dynamic>?>(
                      future:
                          Provider.of<DatabaseService>(context, listen: false)
                              .getClassById(timetable.classId),
                      builder: (context, classSnapshot) {
                        if (classSnapshot.connectionState ==
                            ConnectionState.waiting) {
                          return ListTile(
                            title: Text(timetable.timeSlot),
                            subtitle: Text('Loading class details...'),
                          );
                        }
                        if (classSnapshot.hasError) {
                          return ListTile(
                            title: Text(timetable.timeSlot),
                            subtitle: Text(
                                'Error loading class: ${classSnapshot.error}'),
                          );
                        }
                        final classData = classSnapshot.data ?? {};
                        return ListTile(
                          title: Text(timetable.timeSlot),
                          subtitle: Text(
                              '${classData['subject'] ?? 'Unknown'} (Grade ${classData['grade'] ?? 'Unknown'})'),
                        );
                      },
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
