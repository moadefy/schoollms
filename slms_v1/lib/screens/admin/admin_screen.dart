import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schoollms/services/database_service.dart';

class AdminScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Admin Dashboard')),
      body: ListView(
        padding: EdgeInsets.all(16.0),
        children: [
          Text('Configure Timetable Slots', style: TextStyle(fontSize: 18)),
          Text('Manage Subject Colors', style: TextStyle(fontSize: 18)),
          Text('Set Minimum Learners', style: TextStyle(fontSize: 18)),
          Text('Announcements', style: TextStyle(fontSize: 18)),
          Text('Support Issues', style: TextStyle(fontSize: 18)),
          Text('Subscription Management', style: TextStyle(fontSize: 18)),
          // Add basic forms or placeholders for these features
        ],
      ),
    );
  }
}
