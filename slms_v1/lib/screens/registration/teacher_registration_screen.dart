import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:schoollms/models/teacher.model.dart' as TeacherModel;
import 'package:schoollms/models/learner.model.dart' as LearnerModel;
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

  // Learner registration fields
  final learnerCitizenshipIdController = TextEditingController();
  final learnerNameController = TextEditingController();
  final learnerSurnameController = TextEditingController();
  final learnerGradeController = TextEditingController();

  @override
  void dispose() {
    learnerCitizenshipIdController.dispose();
    learnerNameController.dispose();
    learnerSurnameController.dispose();
    learnerGradeController.dispose();
    super.dispose();
  }

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
              const Text(
                'Register a Learner',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextFormField(
                controller: learnerCitizenshipIdController,
                decoration:
                    const InputDecoration(labelText: 'Learner Citizenship ID'),
                onChanged: (val) => learnerCitizenshipIdController.text = val,
              ),
              TextFormField(
                controller: learnerNameController,
                decoration: const InputDecoration(labelText: 'Learner Name'),
                onChanged: (val) => learnerNameController.text = val,
              ),
              TextFormField(
                controller: learnerSurnameController,
                decoration: const InputDecoration(labelText: 'Learner Surname'),
                onChanged: (val) => learnerSurnameController.text = val,
              ),
              TextFormField(
                controller: learnerGradeController,
                decoration: const InputDecoration(labelText: 'Learner Grade'),
                onChanged: (val) => learnerGradeController.text = val,
              ),
              ElevatedButton(
                onPressed: () async {
                  _formKey.currentState!.save();
                  final teacherId = const Uuid().v4();
                  final teacher = TeacherModel.TeacherData(
                    id: teacherId,
                    country: country,
                    citizenshipId: citizenshipId,
                    name: name,
                    surname: surname,
                    homeLanguage: homeLanguage,
                    preferredLanguage: preferredLanguage,
                    qualifiedSubjects: qualifiedSubjects,
                    supportingDocuments: supportingDocuments,
                  );
                  await db.insertTeacherData(teacher);

                  // Register learner under teacher's credentials
                  final learnerId = const Uuid().v4();
                  final learner = LearnerModel.LearnerData(
                    id: learnerId,
                    country: country, // Use teacher's country
                    citizenshipId: learnerCitizenshipIdController.text,
                    name: learnerNameController.text,
                    surname: learnerSurnameController.text,
                    homeLanguage: '', // Placeholder
                    preferredLanguage: '', // Placeholder
                    grade: learnerGradeController.text,
                    subjects: [], // Placeholder
                    parentDetails: LearnerModel.ParentDetails(
                      id: '', // Placeholder
                      name: '',
                      surname: '',
                      email: '',
                      contactNumber: '',
                      occupation: '',
                    ),
                  );
                  await db.insertLearnerData(learner);

                  Navigator.pushReplacementNamed(context, '/profile',
                      arguments: {
                        'userId': teacherId,
                        'role': 'teacher',
                      });
                },
                child: const Text('Register Teacher & Learner'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
