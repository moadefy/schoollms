import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schoollms/services/database_service.dart';
import 'package:schoollms/models/user.dart';

class ProfileScreen extends StatelessWidget {
  final String userId;

  ProfileScreen({required this.userId});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: FutureBuilder<User?>(
        future: db.getUserDataById(userId),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());
          final user = snapshot.data!;
          final roleData = user.roleData;

          return ListView(
            padding: EdgeInsets.all(16.0),
            children: [
              Text('Name: ${user.name} ${user.surname}'),
              Text('Country: ${user.country}'),
              Text('Citizenship ID: ${user.citizenshipId}'),
              Text('Role: ${user.role}'),
              if (roleData.containsKey('grade'))
                Text('Grade: ${roleData['grade']}'),
              if (roleData.containsKey('qualifiedSubjects'))
                Text('Subjects: ${roleData['qualifiedSubjects'].toString()}'),
              if (roleData.containsKey('learnerId'))
                Text('Associated Learner ID: ${roleData['learnerId']}'),
            ],
          );
        },
      ),
    );
  }
}
