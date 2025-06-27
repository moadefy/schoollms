import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:schoollms/models/user.dart';
import 'package:schoollms/services/database_service.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:schoollms/models/language.dart';
import 'package:schoollms/models/grade.dart';
import 'package:schoollms/models/subject.dart';
import 'package:file_picker/file_picker.dart';

class LearnerRegistrationScreen extends StatefulWidget {
  @override
  _LearnerRegistrationScreenState createState() =>
      _LearnerRegistrationScreenState();
}

class _LearnerRegistrationScreenState extends State<LearnerRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  String country = 'ZA',
      citizenshipId = '',
      name = '',
      surname = '',
      homeLanguageId = '',
      preferredLanguageId = '',
      gradeId = '';
  List<String> subjectIds = [];
  List<String> supportingDocuments = [];
  List<Map<String, String>> parentDetails = [
    {
      'id': '',
      'name': '',
      'surname': '',
      'email': '',
      'contactNumber': '',
      'occupation': '',
    }
  ];
  final List<Language> _languages = [];
  final List<Grade> _grades = [];
  final List<Subject> _subjects = [];
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
          gradeId = ''; // Default to no selection
          _isLoading = false;
        });
        print(
            'Loaded subjects: ${subjects.map((s) => '${s.name}: ${s.gradeIds}').join(', ')}');
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
    // Convert gradeId to match the format expected by gradeIds (e.g., number to UUID)
    final selectedGrade = _grades.firstWhere(
      (grade) => grade.id == gradeId,
      orElse: () => Grade(id: '', number: ''),
    );
    final gradeNumber =
        selectedGrade.number.isNotEmpty ? selectedGrade.number : null;

    // Filter subjects based on the selected grade number
    final filteredSubjects = gradeNumber != null
        ? _subjects.where((subject) {
            print(
                'Subject: ${subject.name}, gradeIds: ${subject.gradeIds}, checking $gradeNumber');
            return subject.gradeIds.contains(gradeNumber);
          }).toList()
        : [];
    print(
        'Filtered subjects for gradeNumber $gradeNumber: ${filteredSubjects.map((s) => s.name).join(', ')}');

    return Scaffold(
      appBar: AppBar(title: const Text('Learner Registration')),
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
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Grade'),
                      value:
                          gradeId.isEmpty ? null : gradeId, // Default to null
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
                      onChanged: (val) {
                        setState(() {
                          gradeId = val ?? '';
                          subjectIds.clear(); // Clear previous selections
                        });
                      },
                      validator: (val) => val == null || val.isEmpty
                          ? 'Please select a grade'
                          : null,
                    ),
                    // Multi-select subjects filtered by grade
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Select Subjects',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Container(
                          height: 150, // Adjustable height for the list
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: filteredSubjects.length,
                            itemBuilder: (context, index) {
                              final subject = filteredSubjects[index];
                              final isSelected =
                                  subjectIds.contains(subject.id);
                              return CheckboxListTile(
                                title: Text(subject.name),
                                value: isSelected,
                                onChanged: (bool? value) {
                                  setState(() {
                                    if (value == true) {
                                      subjectIds.add(subject.id);
                                    } else {
                                      subjectIds.remove(subject.id);
                                    }
                                  });
                                },
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                              );
                            },
                          ),
                        ),
                        if (subjectIds.isEmpty && filteredSubjects.isNotEmpty)
                          const Text(
                            'At least one subject is required',
                            style: TextStyle(color: Colors.red),
                          ),
                      ],
                    ),
                    _buildParentDetailsSection(),
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
                            subjectIds.isNotEmpty) {
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
                              'selectedGrade': gradeId,
                              'selectedSubjects': subjectIds,
                              'parentDetails': parentDetails,
                              'supportingDocuments': supportingDocuments,
                              'homeLanguageId': homeLanguageId,
                              'preferredLanguageId': preferredLanguageId,
                            },
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
                                  SnackBar(
                                      content: Text('Error registering: $e')));
                          }
                        } else if (subjectIds.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Please select at least one subject')),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content:
                                    Text('Please fill all required fields')),
                          );
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

  Widget _buildParentDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Parent Details',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        ListView.builder(
          shrinkWrap: true,
          physics: NeverScrollableScrollPhysics(),
          itemCount: parentDetails.length + 1,
          itemBuilder: (context, index) {
            if (index == parentDetails.length) {
              return ElevatedButton(
                onPressed: () {
                  setState(() {
                    parentDetails.add({
                      'id': '',
                      'name': '',
                      'surname': '',
                      'email': '',
                      'contactNumber': '',
                      'occupation': '',
                    });
                  });
                },
                child: const Text('Add Parent'),
              );
            }
            return Column(
              children: [
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Parent ID'),
                  validator: (val) =>
                      val!.isEmpty ? 'Parent ID is required' : null,
                  onChanged: (val) =>
                      setState(() => parentDetails[index]['id'] = val),
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Parent Name'),
                  validator: (val) =>
                      val!.isEmpty ? 'Parent Name is required' : null,
                  onChanged: (val) =>
                      setState(() => parentDetails[index]['name'] = val),
                ),
                TextFormField(
                  decoration:
                      const InputDecoration(labelText: 'Parent Surname'),
                  validator: (val) =>
                      val!.isEmpty ? 'Parent Surname is required' : null,
                  onChanged: (val) =>
                      setState(() => parentDetails[index]['surname'] = val),
                ),
                TextFormField(
                  decoration: const InputDecoration(labelText: 'Parent Email'),
                  validator: (val) => val!.isEmpty || !val.contains('@')
                      ? 'Valid email is required'
                      : null,
                  onChanged: (val) =>
                      setState(() => parentDetails[index]['email'] = val),
                ),
                TextFormField(
                  decoration:
                      const InputDecoration(labelText: 'Parent Contact'),
                  validator: (val) => val!.isEmpty || val.length < 10
                      ? 'Valid contact is required'
                      : null,
                  onChanged: (val) => setState(
                      () => parentDetails[index]['contactNumber'] = val),
                ),
                TextFormField(
                  decoration:
                      const InputDecoration(labelText: 'Parent Occupation'),
                  validator: (val) =>
                      val!.isEmpty ? 'Occupation is required' : null,
                  onChanged: (val) =>
                      setState(() => parentDetails[index]['occupation'] = val),
                ),
                IconButton(
                  icon: const Icon(Icons.remove_circle),
                  onPressed: () {
                    setState(() {
                      if (parentDetails.length > 1) {
                        parentDetails.removeAt(index);
                      }
                    });
                  },
                ),
                const SizedBox(height: 10),
              ],
            );
          },
        ),
      ],
    );
  }
}
