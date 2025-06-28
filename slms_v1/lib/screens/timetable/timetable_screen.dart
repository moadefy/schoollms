import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:schoollms/services/database_service.dart';
import 'package:schoollms/models/user.dart';
import 'package:schoollms/models/class.model.dart';
import 'package:schoollms/models/timetable.dart';
import 'package:schoollms/models/timetable_slot.dart';
import 'package:schoollms/models/assessment.dart';
import 'package:schoollms/models/question.dart';
import 'package:schoollms/models/answer.dart';
import 'package:schoollms/models/asset.dart';
import 'package:schoollms/models/analytics.dart';
import 'package:schoollms/models/learnertimetable.dart';
import 'package:schoollms/widgets/canvas_widget.dart';
import 'package:schoollms/screens/canvas/teacher_canvas_screen.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:schoollms/models/subject.dart';
import 'package:schoollms/models/grade.dart';
import 'package:schoollms/models/language.dart';

class TimetableScreen extends StatefulWidget {
  @override
  _TimetableScreenState createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late String userId;
  late String role;
  late List<Map<String, dynamic>> timetableSlots = [];
  late List<User> learners = [];
  final List<String> timeSlots = [
    '09:00-10:00',
    '10:00-11:00',
    '11:00-12:00',
    '12:00-13:00',
    '13:00-14:00',
  ];
  late DateTime selectedDay;
  String? deviceId;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    selectedDay = DateTime.now();
    deviceId = null;
    isLoading = true;
    errorMessage = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null) {
      userId = 'default_user_id';
      role = 'guest';
      errorMessage = 'No user data provided. Please log in.';
      setState(() {});
    } else {
      userId = args['userId'] as String? ?? 'default_user_id';
      role = args['role'] as String? ?? 'guest';
    }
    if (deviceId == null) _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      await _initializeDeviceId();
      await _loadTimetableSlots();
    } catch (e) {
      if (mounted) setState(() => errorMessage = 'Error loading data: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _initializeDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Theme.of(context).platform == TargetPlatform.android) {
      final androidInfo = await deviceInfo.androidInfo;
      if (mounted) setState(() => deviceId = androidInfo.id);
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      final iosInfo = await deviceInfo.iosInfo;
      if (mounted) setState(() => deviceId = iosInfo.identifierForVendor);
    } else {
      if (mounted) setState(() => deviceId = 'teacher_device_$userId');
    }
  }

  Future<void> _loadTimetableSlots() async {
    setState(() => isLoading = true);
    try {
      final db = Provider.of<DatabaseService>(context, listen: false);
      if (role == 'teacher') {
        final slots = await db.getTeacherTimetableSlots(userId);
        setState(() {
          timetableSlots = slots.isEmpty
              ? [
                  {'timeSlot': '09:00-10:00', 'subject': 'Math'},
                  {'timeSlot': '10:00-11:00', 'subject': 'Science'},
                ]
              : slots;
          isLoading = false;
          if (timetableSlots.isEmpty)
            errorMessage =
                'No timetables found. Add a new timetable to get started.';
        });
      } else if (role == 'learner') {
        final user = await db.getUserDataById(userId);
        List<Map<String, dynamic>> slots = [];
        if (user != null && user.roleData.containsKey('selectedGrade')) {
          slots = await db.getLearnerTimetableSlots(userId);
        }
        setState(() {
          timetableSlots = slots;
          isLoading = false;
        });
      } else if (role == 'parent') {
        setState(() {
          timetableSlots = [];
          isLoading = false;
        });
      } else if (role == 'admin') {
        List<Map<String, dynamic>> slots = await db.getAllTimetableSlots();
        setState(() {
          timetableSlots = slots;
          isLoading = false;
        });
      } else if (role == 'guest') {
        setState(() {
          timetableSlots = [];
          errorMessage = 'Please log in to view timetables.';
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          errorMessage = 'Error loading timetable: $e';
          isLoading = false;
        });
    }
  }

  Future<void> _showAddTimetableDialog(
      BuildContext context, int slotIndex) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final subjects = await db.getAllSubjects();
    final grades = await db.getAllGrades();
    var classes = await db.getTeacherClassDataByTeacherId(userId);

    bool isAddingNewClass = classes.isEmpty;
    String? selectedClassId;
    String? selectedSubjectId;
    String? selectedGradeId;
    List<String> selectedLearnerIds = [];
    List<User> existingLearners = [];

    // Fetch user data and handle as User object
    final userData = await db.getUserDataById(userId);
    final qualifiedSubjects =
        userData?.roleData['qualifiedSubjects'] as List<Map<String, String>>? ??
            [];

    await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(builder: (context, setState) {
              // Filter subjects based on qualifiedSubjects
              final qualifiedSubjectIds = qualifiedSubjects
                  .map((qs) => qs['subjectId'])
                  .whereType<String>()
                  .toSet();
              final filteredSubjects = subjects
                  .where((s) => qualifiedSubjectIds.contains(s.id))
                  .toList();

              // Filter grades based on qualifiedSubjects and the selected subject
              final filteredGrades = grades.where((g) {
                return qualifiedSubjects.any((qs) =>
                    qs['subjectId'] == selectedSubjectId &&
                    qs['gradeId'] == g.id);
              }).toList();

              return AlertDialog(
                title:
                    Text(isAddingNewClass ? 'Add New Class' : 'Select Class'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isAddingNewClass)
                      Column(
                        children: [
                          DropdownButton<String>(
                            hint: const Text('Select Subject'),
                            value: selectedSubjectId,
                            items: filteredSubjects
                                .map((s) => DropdownMenuItem<String>(
                                      value: s.id,
                                      child: Text(s.name),
                                    ))
                                .toList(),
                            onChanged: (value) {
                              setState(() {
                                selectedSubjectId = value;
                                selectedGradeId =
                                    null; // Reset grade when subject changes
                              });
                            },
                          ),
                          DropdownButton<String>(
                            hint: const Text('Select Grade'),
                            value: selectedGradeId,
                            items: filteredGrades
                                .map((g) => DropdownMenuItem<String>(
                                      value: g.id,
                                      child: Text('Grade ${g.number}'),
                                    ))
                                .toList(),
                            onChanged: (value) =>
                                setState(() => selectedGradeId = value),
                          ),
                        ],
                      )
                    else
                      DropdownButton<String>(
                        hint: const Text('Select Class'),
                        value: selectedClassId,
                        items: classes
                            .map((cls) => DropdownMenuItem<String>(
                                  value: cls.id,
                                  child: Text(cls.title),
                                ))
                            .toList(),
                        onChanged: (value) async {
                          setState(() => selectedClassId = value);
                          if (value != null) {
                            existingLearners = await _loadLearners(value);
                            setState(() => learners = existingLearners);
                          }
                        },
                      ),
                    if (!isAddingNewClass && selectedClassId != null)
                      ElevatedButton(
                        onPressed: () async {
                          final classData =
                              await db.getClassDataById(selectedClassId!);
                          final classGradeId = classData?.gradeId;
                          final result = await showDialog<List<String>>(
                            context: context,
                            builder: (context) => LearnerSelectionDialog(
                              learners: learners,
                              onAddNew: () async {
                                if (classGradeId != null) {
                                  await _showAddLearnerDialog(
                                      context, classGradeId);
                                }
                              },
                              classGradeId: classGradeId,
                            ),
                          );
                          if (result != null)
                            setState(() => selectedLearnerIds = result);
                        },
                        child: Text(
                            'Select/Add Learners (${selectedLearnerIds.length})'),
                      ),
                    if (!isAddingNewClass)
                      ElevatedButton(
                        onPressed: () =>
                            setState(() => isAddingNewClass = true),
                        child: const Text('Add New Class'),
                      ),
                  ],
                ),
                actions: [
                  if (isAddingNewClass)
                    TextButton(
                      onPressed: () async {
                        if (selectedSubjectId != null &&
                            selectedGradeId != null) {
                          final existingClasses =
                              await db.getTeacherClassDataByTeacherId(userId);
                          final sameSubjectGradeClasses = existingClasses
                              .where((cls) =>
                                  cls.subjectId == selectedSubjectId &&
                                  cls.gradeId == selectedGradeId)
                              .toList();
                          int classNumber = sameSubjectGradeClasses.isEmpty
                              ? 1
                              : sameSubjectGradeClasses.map((cls) {
                                    final match = RegExp(r'Class (\d+)$')
                                        .firstMatch(cls.title);
                                    return match != null
                                        ? int.parse(match.group(1)!)
                                        : 0;
                                  }).reduce((a, b) => a > b ? a : b) +
                                  1;
                          final subject = filteredSubjects
                              .firstWhere((s) => s.id == selectedSubjectId);
                          final grade =
                              grades.firstWhere((g) => g.id == selectedGradeId);
                          final classTitle =
                              '${subject.name} ${grade.number} Class $classNumber';
                          final newClass = ClassData(
                            id: const Uuid().v4(),
                            teacherId: userId,
                            subjectId: selectedSubjectId!,
                            gradeId: selectedGradeId!,
                            title: classTitle,
                            createdAt: DateTime.now().millisecondsSinceEpoch,
                            learnerIds: [],
                          );
                          try {
                            await db.insertClassData(newClass);
                            setState(() => isAddingNewClass = false);
                            classes =
                                await db.getTeacherClassDataByTeacherId(userId);
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Class added successfully')));
                          } catch (e) {
                            if (mounted)
                              setState(() =>
                                  errorMessage = 'Error adding class: $e');
                          }
                        }
                      },
                      child: const Text('Add Class'),
                    ),
                  TextButton(
                    onPressed: () {
                      if (!isAddingNewClass &&
                          selectedClassId != null &&
                          selectedLearnerIds.isNotEmpty) {
                        _saveTimetableSlot(
                            selectedClassId!, selectedLearnerIds, slotIndex);
                      }
                      Navigator.pop(context);
                    },
                    child: isAddingNewClass
                        ? const Text('Close')
                        : const Text('Save'),
                  ),
                ],
              );
            }));
  }

  Future<void> _saveTimetableSlot(
      String classId, List<String> learnerIds, int slotIndex) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final timeSlot =
        '${selectedDay.toIso8601String().split('T')[0]} ${timeSlots[slotIndex]}';
    final timetableId = const Uuid().v4();
    final slots = [
      {
        'id': const Uuid().v4(),
        'classId': classId,
        'timeSlot': timeSlot,
        'learnerIds': learnerIds,
      },
    ];
    final timetable = Timetable(
      id: timetableId,
      teacherId: userId,
      userRole: 'teacher',
      userId: userId,
    );
    try {
      await db.insertTimetable(timetable, slots);
      await _loadTimetableSlots();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Timetable slot added successfully')));
    } catch (e) {
      if (mounted)
        setState(() => errorMessage = 'Error adding timetable slot: $e');
    }
  }

  Future<void> _showAddLearnerDialog(
      BuildContext context, String? classGradeId) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final learnerNameController = TextEditingController();
    final grades = await db.getAllGrades();
    String? selectedGradeId = classGradeId;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Register New Learner'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: learnerNameController,
              decoration: const InputDecoration(labelText: 'Learner Name'),
            ),
            DropdownButton<String>(
              hint: const Text('Select Grade'),
              value: selectedGradeId,
              items: grades
                  .map((g) => DropdownMenuItem(
                        value: g.id,
                        child: Text('Grade ${g.number}'),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => selectedGradeId = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (learnerNameController.text.isNotEmpty &&
                  selectedGradeId != null &&
                  selectedGradeId == classGradeId) {
                final newUser = User(
                  id: const Uuid().v4(),
                  country: 'ZA',
                  citizenshipId: const Uuid().v4(),
                  name: learnerNameController.text,
                  surname: '',
                  role: 'learner',
                  roleData: {
                    'selectedGrade': selectedGradeId,
                    'selectedSubjects': [],
                  },
                );
                try {
                  await db.insertUserData(newUser);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Learner registered successfully')));
                  setState(() => learners.add(newUser));
                } catch (e) {
                  if (mounted)
                    setState(
                        () => errorMessage = 'Error registering learner: $e');
                }
              } else if (selectedGradeId != classGradeId) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(
                        'Learner grade must match the class grade ($classGradeId)')));
              }
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }

  Future<List<User>> _loadLearners(String classId) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      final classData = await db.getClassDataById(classId);
      if (classData != null) {
        final learnerIds = classData.learnerIds;
        final users =
            await Future.wait(learnerIds.map((id) => db.getUserDataById(id)));
        return users
            .whereType<User>()
            .where((u) =>
                u.role == 'learner' &&
                u.roleData['selectedGrade'] == classData.gradeId)
            .toList();
      }
      return [];
    } catch (e) {
      if (mounted) setState(() => errorMessage = 'Error loading learners: $e');
      return [];
    }
  }

  Future<void> _showAddAssessmentDialog(
      BuildContext context, Timetable timetable) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    String? assessmentType = 'activity';
    int? timerSeconds;
    DateTime? closeTime;

    String? slotId;
    String? classId;
    final slotAssociations =
        await db.getTimetableSlotAssociationsByTimetableId(timetable.id);
    if (slotAssociations.isNotEmpty) {
      slotId = slotAssociations.first.slotId;
      final slots = await db.getTimetableSlotsByTimetableId(timetable.id);
      if (slots.isNotEmpty) {
        classId = slots.first.classId;
      }
    }
    if (slotId == null || classId == null) {
      if (mounted) {
        setState(() =>
            errorMessage = 'No slot or class associated with this timetable');
      }
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Add Assessment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  hint: const Text('Select Assessment Type'),
                  value: assessmentType,
                  items: ['activity', 'test', 'homework', 'assignment', 'exam']
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => assessmentType = value);
                    }
                  },
                ),
                if (assessmentType == 'test' || assessmentType == 'exam')
                  TextField(
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Timer (seconds)'),
                    onChanged: (value) => timerSeconds = int.tryParse(value),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: assessmentType == null
                    ? null
                    : () async {
                        closeTime = timerSeconds != null
                            ? DateTime.now()
                                .add(Duration(seconds: timerSeconds!))
                            : null;
                        final assessment = Assessment(
                          id: const Uuid().v4(),
                          classIds: [classId!],
                          type: assessmentType!,
                          timerSeconds: timerSeconds,
                          closeTime: closeTime,
                          questionIds: [],
                          slotId: slotId,
                        );
                        try {
                          await db.insertAssessment(assessment);
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content:
                                      Text('Assessment added successfully')));
                        } catch (e) {
                          if (mounted) {
                            setState(() =>
                                errorMessage = 'Error adding assessment: $e');
                          }
                        }
                        Navigator.pop(context);
                      },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _openLearnerAssessmentCanvas(
      Timetable timetable, String learnerId) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    String? slotId;
    String? classId;
    final slotAssociations =
        await db.getTimetableSlotAssociationsByTimetableId(timetable.id);
    if (slotAssociations.isNotEmpty) {
      slotId = slotAssociations.first.slotId;
      final slots = await db.getTimetableSlotsByTimetableId(timetable.id);
      if (slots.isNotEmpty) {
        classId = slots.first.classId;
      }
    }
    if (slotId == null || classId == null) return;

    final assessments = await db.getAssessmentsByClass(classId);
    if (assessments.isEmpty) return;

    final questions = await db.getQuestionsByClass(classId);
    final learnerAnswers = await Future.wait(assessments.map((assessment) =>
        Future.wait(assessment.questionIds.map((qId) => db
            .getAnswersByQuestion(qId)
            .then((answers) => answers.firstWhere(
                (a) => a.learnerId == learnerId,
                orElse: () => Answer(
                    id: const Uuid().v4(),
                    questionId: qId,
                    learnerId: learnerId,
                    strokes: [],
                    assets: [],
                    score: 0.0,
                    remarks: '',
                    slotId: slotId)))))));

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('Mark $learnerId\'s Assessment')),
          body: ListView.builder(
            itemCount: learnerAnswers.length,
            itemBuilder: (context, index) {
              final answer = learnerAnswers[index][0];
              return ListTile(
                title: Text('Question ${index + 1}'),
                onTap: () => _markAnswer(timetable, answer),
              );
            },
          ),
        ),
      ),
    );
  }

  Future<void> _markAnswer(Timetable timetable, Answer answer) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    var strokes = jsonEncode(answer.strokes);
    final assets = await db.getAssetsByLearner(answer.learnerId!);
    DateTime startTime = DateTime.now();

    String? slotId;
    final slots = await db.getTimetableSlotsByTimetableId(timetable.id);
    if (slots.isNotEmpty) {
      slotId = slots.first.id;
    } else {
      slotId = answer.slotId ?? const Uuid().v4();
      if (mounted) {
        setState(() => errorMessage =
            'No slots found for timetable ${timetable.id}, using fallback slotId');
      }
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: const Text('Mark Answer'),
            actions: [
              IconButton(
                icon: const Icon(Icons.save),
                onPressed: () async {
                  DateTime endTime = DateTime.now();
                  int timeSpent = endTime.difference(startTime).inSeconds;
                  final updatedAnswer = Answer(
                    id: answer.id,
                    questionId: answer.questionId,
                    learnerId: answer.learnerId,
                    strokes: jsonDecode(strokes),
                    assets: answer.assets,
                    score: await _selectScore(context) ?? answer.score ?? 0.0,
                    remarks:
                        await _selectRemarks(context) ?? answer.remarks ?? '',
                    slotId: slotId,
                  );
                  await db.insertAnswer(updatedAnswer);
                  final analytics = Analytics(
                    questionId: answer.questionId,
                    learnerId: answer.learnerId!,
                    timeSpentSeconds: timeSpent,
                    submissionStatus: 'marked',
                    deviceId: deviceId!,
                    timestamp: endTime.millisecondsSinceEpoch,
                  );
                  await db.insertAnalytics(analytics);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Answer marked')));
                  }
                },
              ),
            ],
          ),
          body: CanvasWidget(
            learnerId: answer.learnerId!,
            strokes: strokes,
            readOnly: false,
            initialAssets: assets
                .map((a) => CanvasAsset(
                      id: a.id,
                      type: a.type,
                      path: a.data,
                      pageIndex: 0,
                      position: Offset(a.positionX, a.positionY),
                      scale: a.scale,
                    ))
                .toList(),
            onSave: () => strokes = jsonEncode(answer.strokes),
            onUpdate: (data) => strokes = jsonEncode(data['strokes']),
            onAssetsUpdate: (updatedAssets) async {
              for (var asset in updatedAssets) {
                await db.insertAsset(Asset(
                  id: const Uuid().v4(),
                  learnerId: answer.learnerId!,
                  questionId: answer.questionId,
                  type: asset.type,
                  data: asset.path,
                  positionX: asset.position.dx,
                  positionY: asset.position.dy,
                  scale: asset.scale,
                  created_at: DateTime.now().millisecondsSinceEpoch,
                ));
              }
            },
            timetableId: timetable.id,
            slotId: slotId,
            userRole: 'teacher',
          ),
        ),
      ),
    );
  }

  Future<void> _openTeacherNotesCanvas(Timetable timetable) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    String? slotId;
    String? classId;
    final slotAssociations =
        await db.getTimetableSlotAssociationsByTimetableId(timetable.id);
    if (slotAssociations.isNotEmpty) {
      slotId = slotAssociations.first.slotId;
      final slots = await db.getTimetableSlotsByTimetableId(timetable.id);
      if (slots.isNotEmpty) {
        classId = slots.first.classId;
      }
    }
    if (slotId == null || classId == null) return;

    var notesQuestion = await db
        .getQuestionsByClass(classId)
        .then((questions) => questions.firstWhere(
              (q) =>
                  jsonDecode(q.content)['type'] == 'notes' &&
                  q.classId == classId,
              orElse: () => Question(
                id: const Uuid().v4(),
                classId: classId!,
                content: jsonEncode({'strokes': [], 'type': 'notes'}),
                pdfPage: null,
                slotId: slotId,
              ),
            ));
    var content = notesQuestion.content;
    final assets = await db.getAssetsByLearner(userId);
    DateTime startTime = DateTime.now();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('Teacher Notes')),
          body: CanvasWidget(
            learnerId: userId,
            strokes: content,
            readOnly: false,
            initialAssets: assets
                .map((a) => CanvasAsset(
                      id: a.id,
                      type: a.type,
                      path: a.data,
                      pageIndex: 0,
                      position: Offset(a.positionX, a.positionY),
                      scale: a.scale,
                    ))
                .toList(),
            onSave: () => content = jsonEncode(jsonDecode(content)),
            onUpdate: (data) => content = jsonEncode(data['strokes']),
            onAssetsUpdate: (updatedAssets) async {
              for (var asset in updatedAssets) {
                await db.insertAsset(Asset(
                  id: const Uuid().v4(),
                  learnerId: userId,
                  questionId: notesQuestion.id,
                  type: asset.type,
                  data: asset.path,
                  positionX: asset.position.dx,
                  positionY: asset.position.dy,
                  scale: asset.scale,
                  created_at: DateTime.now().millisecondsSinceEpoch,
                ));
              }
            },
            timetableId: timetable.id,
            slotId: slotId,
            userRole: 'teacher',
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              DateTime endTime = DateTime.now();
              int timeSpent = endTime.difference(startTime).inSeconds;
              final updatedQuestion = Question(
                id: notesQuestion.id,
                classId: notesQuestion.classId,
                content: content,
                pdfPage: notesQuestion.pdfPage,
                slotId: slotId,
              );
              await db.insertQuestion(updatedQuestion);
              final analytics = Analytics(
                questionId: notesQuestion.id,
                learnerId: userId,
                timeSpentSeconds: timeSpent,
                submissionStatus: 'saved',
                deviceId: deviceId!,
                timestamp: endTime.millisecondsSinceEpoch,
              );
              await db.insertAnalytics(analytics);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Notes saved')));
              }
            },
            child: const Icon(Icons.save),
          ),
        ),
      ),
    );
  }

  Future<void> _postLearnerQuestion(Timetable timetable) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    String? slotId;
    String? classId;
    final slotAssociations =
        await db.getTimetableSlotAssociationsByTimetableId(timetable.id);
    if (slotAssociations.isNotEmpty) {
      slotId = slotAssociations.first.slotId;
      final slots = await db.getTimetableSlotsByTimetableId(timetable.id);
      if (slots.isNotEmpty) {
        classId = slots.first.classId;
      }
    }
    if (slotId == null || classId == null) return;

    var question = Question(
      id: const Uuid().v4(),
      classId: classId,
      content: jsonEncode({'strokes': [], 'type': 'learner_question'}),
      pdfPage: null,
      slotId: slotId,
    );
    var content = question.content;
    final assets = await db.getAssetsByLearner(userId);
    DateTime startTime = DateTime.now();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('Post Learner Question')),
          body: FutureBuilder<void>(
            future: Future.delayed(Duration.zero),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return CanvasWidget(
                  learnerId: userId,
                  strokes: content,
                  readOnly: false,
                  initialAssets: assets
                      .map((a) => CanvasAsset(
                            id: a.id,
                            type: a.type,
                            path: a.data,
                            pageIndex: 0,
                            position: Offset(a.positionX, a.positionY),
                            scale: a.scale,
                          ))
                      .toList(),
                  onSave: () => content = jsonEncode(jsonDecode(content)),
                  onUpdate: (data) => content = jsonEncode(data['strokes']),
                  onAssetsUpdate: (updatedAssets) async {
                    for (var asset in updatedAssets) {
                      await db.insertAsset(Asset(
                        id: const Uuid().v4(),
                        learnerId: userId,
                        questionId: question.id,
                        type: asset.type,
                        data: asset.path,
                        positionX: asset.position.dx,
                        positionY: asset.position.dy,
                        scale: asset.scale,
                        created_at: DateTime.now().millisecondsSinceEpoch,
                      ));
                    }
                  },
                  timetableId: timetable.id,
                  slotId: slotId,
                  userRole: 'teacher',
                );
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              DateTime endTime = DateTime.now();
              int timeSpent = endTime.difference(startTime).inSeconds;
              final updatedQuestion = Question(
                id: question.id,
                classId: question.classId,
                content: content,
                pdfPage: question.pdfPage,
                slotId: slotId,
              );
              await db.insertQuestion(updatedQuestion);
              final analytics = Analytics(
                questionId: question.id,
                learnerId: userId,
                timeSpentSeconds: timeSpent,
                submissionStatus: 'posted',
                deviceId: deviceId!,
                timestamp: endTime.millisecondsSinceEpoch,
              );
              await db.insertAnalytics(analytics);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Question posted')));
              }
            },
            child: const Icon(Icons.send),
          ),
        ),
      ),
    );
  }

  Future<void> _answerLearnerQuestion(
      Timetable timetable, Question question) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    var updatedQuestion = Question(
      id: question.id,
      classId: question.classId,
      content: question.content,
      pdfPage: question.pdfPage,
      slotId: question.slotId,
    );
    var content = updatedQuestion.content;
    final assets = await db.getAssetsByLearner(userId);
    DateTime startTime = DateTime.now();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('Answer Learner Question')),
          body: FutureBuilder<void>(
            future: Future.delayed(Duration.zero),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                return CanvasWidget(
                  learnerId: userId,
                  strokes: content,
                  readOnly: false,
                  initialAssets: assets
                      .map((a) => CanvasAsset(
                            id: a.id,
                            type: a.type,
                            path: a.data,
                            pageIndex: 0,
                            position: Offset(a.positionX, a.positionY),
                            scale: a.scale,
                          ))
                      .toList(),
                  onSave: () => content = jsonEncode(jsonDecode(content)),
                  onUpdate: (data) => content = jsonEncode(data['strokes']),
                  onAssetsUpdate: (updatedAssets) async {
                    for (var asset in updatedAssets) {
                      await db.insertAsset(Asset(
                        id: const Uuid().v4(),
                        learnerId: userId,
                        questionId: question.id,
                        type: asset.type,
                        data: asset.path,
                        positionX: asset.position.dx,
                        positionY: asset.position.dy,
                        scale: asset.scale,
                        created_at: DateTime.now().millisecondsSinceEpoch,
                      ));
                    }
                  },
                  timetableId: timetable.id,
                  slotId: question.slotId,
                  userRole: 'teacher',
                );
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              DateTime endTime = DateTime.now();
              int timeSpent = endTime.difference(startTime).inSeconds;
              final decodedContent = jsonDecode(content);
              decodedContent['answered'] = true;
              updatedQuestion.content = jsonEncode(decodedContent);
              await db.insertQuestion(updatedQuestion);
              final analytics = Analytics(
                questionId: question.id,
                learnerId: userId,
                timeSpentSeconds: timeSpent,
                submissionStatus: 'answered',
                deviceId: deviceId!,
                timestamp: endTime.millisecondsSinceEpoch,
              );
              await db.insertAnalytics(analytics);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Answer posted')));
              }
            },
            child: const Icon(Icons.send),
          ),
        ),
      ),
    );
  }

  Future<void> _showLearnerSelectionDialog(Timetable timetable) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    String? classId;
    final slotAssociations =
        await db.getTimetableSlotAssociationsByTimetableId(timetable.id);
    if (slotAssociations.isNotEmpty) {
      final slotId = slotAssociations.first.slotId;
      final slots = await db.getTimetableSlotsByTimetableId(timetable.id);
      if (slots.isNotEmpty) {
        classId = slots.first.classId;
      }
    }
    if (classId == null) return;

    final classData = await db.getClassDataById(classId);
    if (classData == null) return;
    final learners = await _loadLearners(classId);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Learner'),
        content: Container(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: learners.length,
            itemBuilder: (context, index) {
              final learner = learners[index];
              return ListTile(
                title: Text(learner.name),
                onTap: () {
                  Navigator.pop(context);
                  _openLearnerAssessmentCanvas(timetable, learner.id);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  Future<double?> _selectScore(BuildContext context) async {
    double? score;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Score'),
        content: TextField(
          keyboardType: TextInputType.number,
          onChanged: (value) => score = double.tryParse(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, score),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return score;
  }

  Future<String?> _selectRemarks(BuildContext context) async {
    String? remarks;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Remarks'),
        content: TextField(
          onChanged: (value) => remarks = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, remarks),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return remarks;
  }

  Future<void> _openCanvasForEditing(String questionId) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final question = await db.getQuestionById(questionId);
    if (question != null) {
      final strokes = question.content;
      final assets = await db.getAssetsByQuestion(questionId);
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CanvasWidget(
            learnerId: userId,
            strokes: strokes,
            readOnly: false,
            onSave: () {},
            onUpdate: (data) {
              db.updateQuestion(Question(
                id: questionId,
                classId: question.classId,
                content: jsonEncode(data['strokes']),
                pdfPage: question.pdfPage,
                slotId: question.slotId,
              ));
            },
            initialAssets: assets
                .map((a) => CanvasAsset(
                      id: a.id,
                      type: a.type,
                      path: a.data,
                      pageIndex: 0,
                      position: Offset(a.positionX, a.positionY),
                      scale: a.scale,
                    ))
                .toList(),
            onAssetsUpdate: (updatedAssets) async {
              for (var asset in updatedAssets) {
                await db.insertAsset(Asset(
                  id: const Uuid().v4(),
                  learnerId: userId,
                  questionId: questionId,
                  type: asset.type,
                  data: asset.path,
                  positionX: asset.position.dx,
                  positionY: asset.position.dy,
                  scale: asset.scale,
                  created_at: DateTime.now().millisecondsSinceEpoch,
                ));
              }
            },
            userRole: 'teacher',
            timetableId: timetableSlots.firstWhere(
                (s) => s['timetableId'] == question.slotId,
                orElse: () => {})['timetableId'],
            slotId: question.slotId,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$role Timetable'),
        actions: [
          DropdownButton<String>(
            value: _getRangeLabel(),
            items: [
              const DropdownMenuItem(value: 'Day', child: Text('Day')),
              const DropdownMenuItem(value: 'Week', child: Text('Week')),
              const DropdownMenuItem(value: 'Month', child: Text('Month')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedDay = DateTime.now();
                  if (value == 'Week')
                    selectedDay = selectedDay.add(const Duration(days: 7));
                  if (value == 'Month')
                    selectedDay = selectedDay.add(const Duration(days: 30));
                  _loadTimetableSlots();
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: selectedDay,
                firstDate: DateTime(2023),
                lastDate: DateTime(2030),
              );
              if (selected != null) {
                setState(() {
                  selectedDay = selected;
                  _loadTimetableSlots();
                });
              }
            },
          ),
          if (role == 'teacher')
            IconButton(
              icon: const Icon(Icons.class_),
              onPressed: () => _showAddTimetableDialog(context, 0),
              tooltip: 'Add Class or Timetable',
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height -
                            kToolbarHeight -
                            kBottomNavigationBarHeight),
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 5,
                        childAspectRatio: 1.5,
                      ),
                      itemCount: timeSlots.length,
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemBuilder: (context, index) {
                        final timeSlot = timeSlots[index];
                        final fullTimeSlot =
                            '${selectedDay.toIso8601String().split('T')[0]} $timeSlot';
                        final slot = timetableSlots.firstWhere(
                          (s) => s['timeSlot'] == fullTimeSlot,
                          orElse: () => {},
                        );
                        return GestureDetector(
                          onTap: slot.isEmpty && role == 'teacher'
                              ? () => _showAddTimetableDialog(context, index)
                              : () {
                                  if (slot['questionId'] != null) {
                                    _openCanvasForEditing(slot['questionId']);
                                  }
                                },
                          child: Card(
                            color: slot.isEmpty
                                ? Colors.green[100]
                                : _getSubjectColor(
                                    slot['subject'] ?? 'Unknown'),
                            child: FutureBuilder<int>(
                              future: slot.isNotEmpty && slot['classId'] != null
                                  ? Provider.of<DatabaseService>(context,
                                          listen: false)
                                      .getClassDataById(slot['classId'])
                                      .then((classData) =>
                                          classData?.learnerIds.length ?? 0)
                                      .catchError((_) => 0)
                                  : Future.value(0),
                              builder: (context, snapshot) {
                                int learnerCount = snapshot.data ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(timeSlot,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold)),
                                      if (slot.isNotEmpty)
                                        Column(
                                          children: [
                                            Text(
                                                'Subject: ${slot['subject'] ?? 'Unknown'}'),
                                            Text(
                                                'Grade: ${slot['grade'] ?? 'Unknown'}'),
                                            Text('Learners: $learnerCount'),
                                            if (slot['questionId'] != null)
                                              TextButton(
                                                onPressed: () =>
                                                    _openCanvasForEditing(
                                                        slot['questionId']),
                                                child: Text('Edit Question'),
                                              ),
                                            if (role == 'teacher')
                                              PopupMenuButton<String>(
                                                onSelected: (value) async {
                                                  final timetable = Timetable(
                                                    id: slot['timetableId']
                                                        as String,
                                                    teacherId: userId,
                                                    userRole: 'teacher',
                                                    userId: userId,
                                                  );
                                                  if (value ==
                                                      'add_assessment') {
                                                    await _showAddAssessmentDialog(
                                                        context, timetable);
                                                  } else if (value ==
                                                      'open_notes') {
                                                    await _openTeacherNotesCanvas(
                                                        timetable);
                                                  } else if (value ==
                                                      'post_question') {
                                                    await _postLearnerQuestion(
                                                        timetable);
                                                  } else if (value ==
                                                      'select_learner') {
                                                    await _showLearnerSelectionDialog(
                                                        timetable);
                                                  }
                                                },
                                                itemBuilder: (context) => [
                                                  const PopupMenuItem(
                                                      value: 'add_assessment',
                                                      child: Text(
                                                          'Add Assessment')),
                                                  const PopupMenuItem(
                                                      value: 'open_notes',
                                                      child:
                                                          Text('Open Notes')),
                                                  const PopupMenuItem(
                                                      value: 'post_question',
                                                      child: Text(
                                                          'Post Question')),
                                                  const PopupMenuItem(
                                                      value: 'select_learner',
                                                      child: Text(
                                                          'Select Learner')),
                                                ],
                                              ),
                                          ],
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
      floatingActionButton: role == 'teacher'
          ? FloatingActionButton(
              onPressed: () => _showAddTimetableDialog(context, 0),
              child: const Icon(Icons.add),
              tooltip: 'Add Timetable Slot',
            )
          : null,
    );
  }

  String _getRangeLabel() {
    if (selectedDay.day == DateTime.now().day &&
        selectedDay.month == DateTime.now().month &&
        selectedDay.year == DateTime.now().year) {
      return 'Day';
    } else if (selectedDay.difference(DateTime.now()).inDays <= 7) {
      return 'Week';
    } else {
      return 'Month';
    }
  }

  Color _getSubjectColor(String subject) {
    switch (subject.toLowerCase()) {
      case 'math':
        return Colors.red;
      case 'science':
        return Colors.blue;
      case 'english':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}

class LearnerSelectionDialog extends StatefulWidget {
  final List<User> learners;
  final Future<void> Function() onAddNew;
  final String? classGradeId;

  LearnerSelectionDialog(
      {required this.learners, required this.onAddNew, this.classGradeId});

  @override
  _LearnerSelectionDialogState createState() => _LearnerSelectionDialogState();
}

class _LearnerSelectionDialogState extends State<LearnerSelectionDialog> {
  late List<String> selectedLearnerIds;

  @override
  void initState() {
    super.initState();
    selectedLearnerIds = [];
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Learners'),
      content: Container(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListView.builder(
              shrinkWrap: true,
              itemCount: widget.learners.length,
              itemBuilder: (context, index) {
                final learner = widget.learners[index];
                final learnerGradeId =
                    learner.roleData['selectedGrade'] as String?;
                final isValidGrade = widget.classGradeId == null ||
                    learnerGradeId == widget.classGradeId;
                return CheckboxListTile(
                  title: Text(learner.name),
                  subtitle: Text('Grade: ${learnerGradeId ?? "Unknown"}'),
                  value:
                      selectedLearnerIds.contains(learner.id) && isValidGrade,
                  onChanged: isValidGrade
                      ? (value) {
                          setState(() {
                            if (value!)
                              selectedLearnerIds.add(learner.id);
                            else
                              selectedLearnerIds.remove(learner.id);
                          });
                        }
                      : null,
                  tristate: !isValidGrade,
                  activeColor: isValidGrade ? null : Colors.grey,
                );
              },
            ),
            TextButton(
              onPressed: () async {
                await widget.onAddNew();
                Navigator.pop(context);
              },
              child: const Text('Add New Learner'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, selectedLearnerIds),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
