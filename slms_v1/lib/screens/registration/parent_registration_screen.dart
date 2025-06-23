import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:schoollms/models/user.dart';
import 'package:schoollms/services/database_service.dart';

class ParentRegistrationScreen extends StatefulWidget {
  final String learnerId;

  ParentRegistrationScreen({required this.learnerId});

  @override
  _ParentRegistrationScreenState createState() =>
      _ParentRegistrationScreenState();
}

class _ParentRegistrationScreenState extends State<ParentRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  String country = '', citizenshipId = '';

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: Text('Parent Registration')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16.0),
          children: [
            TextFormField(
                decoration: InputDecoration(labelText: 'Country'),
                onSaved: (val) => country = val!),
            TextFormField(
                decoration: InputDecoration(labelText: 'Citizenship ID'),
                onSaved: (val) => citizenshipId = val!),
            ElevatedButton(
              onPressed: () async {
                _formKey.currentState!.save();
                final parentId = Uuid().v4();
                final parent = User(
                    id: parentId,
                    country: country,
                    citizenshipId: citizenshipId,
                    name: '',
                    surname: '');
                await db.insertUser(parent); // Assume insertUser for parents
                // Link parent to learner (e.g., update learner's parentDetails)
                final learner = await db.getLearnerDataById(widget.learnerId);
                if (learner != null) {
                  await db.updateLearnerData(learner.copyWith(id: parentId));
                }
                Navigator.pushReplacementNamed(context, '/login');
              },
              child: Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}
