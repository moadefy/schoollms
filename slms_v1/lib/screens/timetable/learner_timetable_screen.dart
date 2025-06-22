import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schoollms/services/database_service.dart';
import 'package:schoollms/providers/sync_state.dart';
import 'package:schoollms/models/learnertimetable.dart';
import 'package:schoollms/models/timetable.dart';
import 'package:schoollms/models/timetable_slot.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:schoollms/widgets/canvas_widget.dart';

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
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: Provider.of<DatabaseService>(context, listen: false)
                  .getLearnerTimetableSlots(learnerId),
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
                final slots = snapshot.data!;
                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5, // Adjust for weekly view (5 days)
                    childAspectRatio: 1.5,
                  ),
                  itemCount: slots.length,
                  itemBuilder: (context, index) {
                    final slot = slots[index];
                    final timeSlot = slot['timeSlot']?.split(' ').last ?? 'N/A';
                    final subject = slot['subject'] ?? 'Unknown';
                    final grade = slot['grade'] ?? 'Unknown';
                    final slotId = slot['slot_id'] ??
                        Uuid().v4(); // Ensure slotId is available

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CanvasWidget(
                              learnerId: learnerId,
                              strokes: jsonEncode([]), // Initial empty strokes
                              readOnly: false,
                              onSave: () {},
                              onUpdate: (data) {},
                              timetableId: slot['timetableId'],
                              slotId: slotId,
                              userRole: 'learner',
                            ),
                          ),
                        );
                      },
                      child: Card(
                        color: _getSubjectColor(subject),
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(timeSlot,
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              Text('Subject: $subject'),
                              Text('Grade: $grade'),
                            ],
                          ),
                        ),
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

  Color _getSubjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'math':
        return Colors.red;
      case 'science':
        return Colors.blue;
      case 'english':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
