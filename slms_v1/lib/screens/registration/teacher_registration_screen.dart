import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:schoollms/models/user.dart';
import 'package:schoollms/services/database_service.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:schoollms/models/language.dart';
import 'package:schoollms/models/subject.dart';
import 'package:schoollms/models/grade.dart';
import 'package:file_picker/file_picker.dart';

class TeacherRegistrationScreen extends StatefulWidget {
  @override
  _TeacherRegistrationScreenState createState() =>
      _TeacherRegistrationScreenState();
}

class _TeacherRegistrationScreenState extends State<TeacherRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  String country = 'ZA',
      citizenshipId = '',
      name = '',
      surname = '',
      homeLanguageId = '',
      preferredLanguageId = '';
  List<Map<String, String>> qualifiedSubjects =
      []; // List of {subjectId, gradeId}
  List<String> supportingDocuments = []; // List of file paths
  final List<Language> _languages = [];
  final List<Subject> _subjects = [];
  final List<Grade> _grades = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      final db = Provider.of<DatabaseService>(context, listen: false);
      final languagesFuture = db.getAllLanguages();
      final gradesFuture = db.getAllGrades();
      final subjectsFuture = db.getAllSubjects();

      final results =
          await Future.wait([languagesFuture, gradesFuture, subjectsFuture]);
      final languages = results[0] as List<Language>;
      final grades = results[1] as List<Grade>;
      final subjects = results[2] as List<Subject>;

      if (mounted) {
        setState(() {
          _languages.addAll(languages);
          _grades.addAll(grades);
          _subjects.addAll(subjects);
          homeLanguageId = languages.isNotEmpty ? languages[0].id : '';
          preferredLanguageId = languages.isNotEmpty ? languages[0].id : '';
          _isLoading = false;
          // Initialize with a default entry if data is available
          if (qualifiedSubjects.isEmpty &&
              _subjects.isNotEmpty &&
              _grades.isNotEmpty) {
            qualifiedSubjects.add(
                {'subjectId': '', 'gradeId': ''}); // Default to no selection
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  Future<void> _pickSupportingDocuments() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'jpg', 'png'],
    );

    if (result != null) {
      setState(() {
        supportingDocuments.addAll(result.paths.whereType<String>());
      });
    } else {
      // User canceled the picker
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Registration')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                          setState(() => country = code.code!);
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
                      decoration:
                          const InputDecoration(labelText: 'Citizenship ID'),
                      validator: (val) =>
                          val!.isEmpty ? 'Citizenship ID is required' : null,
                      onChanged: (val) => setState(() => citizenshipId = val),
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (val) =>
                          val!.isEmpty ? 'Name is required' : null,
                      onChanged: (val) => setState(() => name = val),
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Surname'),
                      validator: (val) =>
                          val!.isEmpty ? 'Surname is required' : null,
                      onChanged: (val) => setState(() => surname = val),
                    ),
                    DropdownButtonFormField<String>(
                      decoration:
                          const InputDecoration(labelText: 'Home Language'),
                      value: homeLanguageId.isNotEmpty ? homeLanguageId : null,
                      items: _languages.map((lang) {
                        return DropdownMenuItem<String>(
                          value: lang.id,
                          child: Text(lang.name),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => homeLanguageId = val!),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Home language is required'
                          : null,
                    ),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                          labelText: 'Preferred Language'),
                      value: preferredLanguageId.isNotEmpty
                          ? preferredLanguageId
                          : null,
                      items: _languages.map((lang) {
                        return DropdownMenuItem<String>(
                          value: lang.id,
                          child: Text(lang.name),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setState(() => preferredLanguageId = val!),
                      validator: (val) => val == null || val.isEmpty
                          ? 'Preferred language is required'
                          : null,
                    ),
                    _buildSubjectGradeSelection(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Supporting Documents',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8.0,
                          children: supportingDocuments.map((path) {
                            return Chip(
                              label: Text(path.split('/').last),
                              onDeleted: () {
                                setState(() {
                                  supportingDocuments.remove(path);
                                });
                              },
                            );
                          }).toList(),
                        ),
                        ElevatedButton(
                          onPressed: _pickSupportingDocuments,
                          child: const Text('Attach Documents'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () async {
                        if (_formKey.currentState!.validate() &&
                            qualifiedSubjects.any((q) =>
                                q['subjectId']!.isNotEmpty &&
                                q['gradeId']!.isNotEmpty)) {
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
                              'qualifiedSubjects': qualifiedSubjects
                                  .where((q) =>
                                      q['subjectId']!.isNotEmpty &&
                                      q['gradeId']!.isNotEmpty)
                                  .map((q) => {
                                        'subjectId': q['subjectId'],
                                        'gradeId': q['gradeId'],
                                      })
                                  .toList(),
                              'supportingDocuments': supportingDocuments,
                              'homeLanguageId': homeLanguageId,
                              'preferredLanguageId': preferredLanguageId,
                            },
                          );
                          try {
                            await db.insertUserData(teacher);
                            Navigator.pushReplacementNamed(
                                context, '/timetable',
                                arguments: {
                                  'userId': teacherId,
                                  'role': 'teacher',
                                });
                          } catch (e) {
                            if (mounted)
                              ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Error registering: $e')));
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text(
                                    'Please select at least one subject and grade combination')),
                          );
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

  Widget _buildSubjectGradeSelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Qualified Subjects and Grades',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: qualifiedSubjects.length + 1,
          itemBuilder: (context, index) {
            if (index == qualifiedSubjects.length) {
              return ElevatedButton(
                onPressed: _subjects.isNotEmpty && _grades.isNotEmpty
                    ? () {
                        setState(() {
                          qualifiedSubjects
                              .add({'subjectId': '', 'gradeId': ''});
                        });
                      }
                    : null,
                child: const Text('Add Subject'),
              );
            }
            return Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Subject'),
                    value: qualifiedSubjects[index]['subjectId']?.isNotEmpty ==
                            true
                        ? qualifiedSubjects[index]['subjectId']
                        : null,
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Select Subject'),
                      ),
                      ..._subjects.map((subject) {
                        return DropdownMenuItem<String>(
                          value: subject.id,
                          child: Text(subject.name),
                        );
                      }).toList(),
                    ],
                    onChanged: (val) => setState(() {
                      qualifiedSubjects[index]['subjectId'] = val ?? '';
                    }),
                    validator: (val) => val == null || val.isEmpty
                        ? 'Please select a subject'
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Grade'),
                    value:
                        qualifiedSubjects[index]['gradeId']?.isNotEmpty == true
                            ? qualifiedSubjects[index]['gradeId']
                            : null,
                    items: [
                      const DropdownMenuItem<String>(
                        value: '',
                        child: Text('Select Grade'),
                      ),
                      ..._grades.map((grade) {
                        return DropdownMenuItem<String>(
                          value: grade.id,
                          child: Text('Grade ${grade.number}'),
                        );
                      }).toList(),
                    ],
                    onChanged: (val) => setState(() {
                      qualifiedSubjects[index]['gradeId'] = val ?? '';
                    }),
                    validator: (val) => val == null || val.isEmpty
                        ? 'Please select a grade'
                        : null,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle),
                  onPressed: qualifiedSubjects.length > 1
                      ? () {
                          setState(() {
                            qualifiedSubjects.removeAt(index);
                          });
                        }
                      : null,
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
