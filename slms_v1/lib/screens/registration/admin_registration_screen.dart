import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:schoollms/models/admin.dart';
import 'package:schoollms/services/database_service.dart';

class AdminRegistrationScreen extends StatefulWidget {
  @override
  _AdminRegistrationScreenState createState() =>
      _AdminRegistrationScreenState();
}

class _AdminRegistrationScreenState extends State<AdminRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  String country = '',
      citizenshipId = '',
      name = '',
      surname = '',
      email = '',
      contactNumber = '';

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: Text('Admin Registration')),
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
            TextFormField(
                decoration: InputDecoration(labelText: 'Name'),
                onSaved: (val) => name = val!),
            TextFormField(
                decoration: InputDecoration(labelText: 'Surname'),
                onSaved: (val) => surname = val!),
            TextFormField(
                decoration: InputDecoration(labelText: 'Email'),
                onSaved: (val) => email = val!),
            TextFormField(
                decoration: InputDecoration(labelText: 'Contact Number'),
                onSaved: (val) => contactNumber = val!),
            ElevatedButton(
              onPressed: () async {
                _formKey.currentState!.save();
                final adminId = Uuid().v4();
                final admin = Admin(
                    id: adminId,
                    country: country,
                    citizenshipId: citizenshipId,
                    name: name,
                    surname: surname,
                    email: email,
                    contactNumber: contactNumber);
                await db.insertUserData(admin); // Assume insertUser for admin
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
