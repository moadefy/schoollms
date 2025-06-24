import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:schoollms/models/user.dart';
import 'package:schoollms/services/database_service.dart';
import 'package:country_code_picker/country_code_picker.dart';

class TeacherRegistrationScreen extends StatefulWidget {
  @override
  _TeacherRegistrationScreenState createState() =>
      _TeacherRegistrationScreenState();
}

class _TeacherRegistrationScreenState extends State<TeacherRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  String country = '',
      citizenshipId = '',
      name = '',
      surname = '',
      homeLanguage = '',
      preferredLanguage = '';
  Map<String, List<String>> qualifiedSubjects = {};
  List<String> supportingDocuments = [];

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Registration')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const Text(
                'Click the flag to select your country',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 5),
              Container(
                padding: EdgeInsets.zero,
                child: CountryCodePicker(
                  onChanged: (CountryCode code) {
                    setState(() => country = code.name!);
                  },
                  initialSelection: 'ZA',
                  favorite: ['ZA', 'US', 'GB'],
                  showFlag: true,
                  showCountryOnly: true,
                  alignLeft: false,
                ),
              ),
              const SizedBox(height: 15),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Citizenship ID'),
                onChanged: (val) => citizenshipId = val,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (val) => name = val,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Surname'),
                onChanged: (val) => surname = val,
              ),
              TextFormField(
                decoration: const InputDecoration(labelText: 'Home Language'),
                onChanged: (val) => homeLanguage = val,
              ),
              TextFormField(
                decoration:
                    const InputDecoration(labelText: 'Preferred Language'),
                onChanged: (val) => preferredLanguage = val,
              ),
              TextFormField(
                decoration: const InputDecoration(
                    labelText: 'Qualified Subjects (e.g., 10:Math,Science)'),
                onChanged: (val) {
                  qualifiedSubjects = {
                    for (var s in (val?.split(',') ?? []))
                      s.split(':')[0]: s.split(':').skip(1).toList()
                  };
                },
              ),
              TextFormField(
                decoration: const InputDecoration(
                    labelText:
                        'Supporting Documents (e.g., Identity Documents, CV, Certificates)'),
                onChanged: (val) => supportingDocuments = val?.split(',') ?? [],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  _formKey.currentState!.save();
                  final teacherId = const Uuid().v4();
                  final teacher = User(
                    id: teacherId,
                    country: country,
                    citizenshipId: citizenshipId,
                    name: name,
                    surname: surname,
                    email: '', // Placeholder
                    contactNumber: '', // Placeholder
                    role: 'teacher',
                    roleData: {
                      'qualifiedSubjects': qualifiedSubjects,
                      'supportingDocuments': supportingDocuments,
                      'homeLanguage': homeLanguage,
                      'preferredLanguage': preferredLanguage,
                    }, // Populate roleData with teacher-specific data
                  );
                  try {
                    await db.insertUserData(teacher);
                    Navigator.pushReplacementNamed(context, '/timetable',
                        arguments: {
                          'userId': teacherId,
                          'role': 'teacher',
                        });
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error registering: $e')));
                  }
                },
                child: const Text('Register Teacher'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
