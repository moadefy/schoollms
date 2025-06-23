import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schoollms/services/database_service.dart';
import 'dart:convert'; // Added to fix jsonDecode error

class ProfileScreen extends StatelessWidget {
  final String userId;

  ProfileScreen({required this.userId});

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: Text('Profile')),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: db.getUserById(userId)
            as Future<Map<String, dynamic>>?, // Fixed type
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return Center(child: CircularProgressIndicator());
          final user = snapshot.data!;
          return ListView(
            padding: EdgeInsets.all(16.0),
            children: [
              Text('Name: ${user['name']} ${user['surname']}'),
              Text('Country: ${user['country']}'),
              Text('Citizenship ID: ${user['citizenshipId']}'),
              if (user.containsKey('grade')) Text('Grade: ${user['grade']}'),
              if (user.containsKey('qualifiedSubjects'))
                Text(
                    'Subjects: ${jsonDecode(user['qualifiedSubjects'])}'), // Fixed with import
            ],
          );
        },
      ),
    );
  }
}
