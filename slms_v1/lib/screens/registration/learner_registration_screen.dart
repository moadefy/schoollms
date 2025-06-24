import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:schoollms/models/user.dart';
import 'package:schoollms/services/database_service.dart';
import 'package:country_code_picker/country_code_picker.dart';

class LearnerRegistrationScreen extends StatefulWidget {
  @override
  _LearnerRegistrationScreenState createState() =>
      _LearnerRegistrationScreenState();
}

class _LearnerRegistrationScreenState extends State<LearnerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  String country = '',
      citizenshipId = '',
      name = '',
      surname = '',
      homeLanguage = '',
      preferredLanguage = '',
      grade = '';
  List<String> subjects = [];
  final parentIdController = TextEditingController();
  final parentNameController = TextEditingController();
  final parentSurnameController = TextEditingController();
  final parentEmailController = TextEditingController();
  final parentContactController = TextEditingController();
  final parentOccupationController = TextEditingController();

  @override
  void dispose() {
    parentIdController.dispose();
    parentNameController.dispose();
    parentSurnameController.dispose();
    parentEmailController.dispose();
    parentContactController.dispose();
    parentOccupationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Learner Registration')),
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
                decoration: const InputDecoration(labelText: 'Grade'),
                onChanged: (val) => grade = val,
              ),
              TextFormField(
                decoration: const InputDecoration(
                    labelText: 'Subjects (comma-separated)'),
                onChanged: (val) => subjects = val!.split(','),
              ),
              TextFormField(
                controller: parentIdController,
                decoration: const InputDecoration(labelText: 'Parent ID'),
                onChanged: (val) => parentIdController.text = val,
              ),
              TextFormField(
                controller: parentNameController,
                decoration: const InputDecoration(labelText: 'Parent Name'),
                onChanged: (val) => parentNameController.text = val,
              ),
              TextFormField(
                controller: parentSurnameController,
                decoration: const InputDecoration(labelText: 'Parent Surname'),
                onChanged: (val) => parentSurnameController.text = val,
              ),
              TextFormField(
                controller: parentEmailController,
                decoration: const InputDecoration(labelText: 'Parent Email'),
                onChanged: (val) => parentEmailController.text = val,
              ),
              TextFormField(
                controller: parentContactController,
                decoration: const InputDecoration(labelText: 'Parent Contact'),
                onChanged: (val) => parentContactController.text = val,
              ),
              TextFormField(
                controller: parentOccupationController,
                decoration:
                    const InputDecoration(labelText: 'Parent Occupation'),
                onChanged: (val) => parentOccupationController.text = val,
              ),
              ElevatedButton(
                onPressed: () async {
                  _formKey.currentState!.save();
                  final learnerId = const Uuid().v4();
                  final learner = User(
                    id: learnerId,
                    country: country,
                    citizenshipId: citizenshipId,
                    name: name,
                    surname: surname,
                    email: '', // Placeholder
                    contactNumber: '', // Placeholder
                    role: 'learner',
                    roleData: {
                      'grade': grade,
                      'subjects': subjects,
                      'parentDetails': {
                        'id': parentIdController.text,
                        'name': parentNameController.text,
                        'surname': parentSurnameController.text,
                        'email': parentEmailController.text,
                        'contactNumber': parentContactController.text,
                        'occupation': parentOccupationController.text,
                      },
                      'homeLanguage': homeLanguage,
                      'preferredLanguage': preferredLanguage,
                    }, // Populate roleData with learner-specific data
                  );
                  try {
                    await db.insertUserData(learner);
                    Navigator.pushReplacementNamed(context, '/profile',
                        arguments: {
                          'userId': learnerId,
                          'role': 'learner',
                        }); // Redirect to profile
                  } catch (e) {
                    if (mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Error registering: $e')));
                  }
                },
                child: const Text('Register'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
