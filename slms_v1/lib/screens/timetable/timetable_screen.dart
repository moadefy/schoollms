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
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    userId = args['userId'];
    role = args['role'];
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
        if (user != null && user.roleData.containsKey('grade')) {
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
    String? selectedClassId;
    List<String> selectedLearnerIds = [];

    var classes = await db.getTeacherClassDataByTeacherId(userId);
    if (classes.isEmpty) {
      await _showAddClassDialog(context);
      classes =
          await db.getTeacherClassDataByTeacherId(userId); // Refresh classes
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Timetable Slot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                hint: const Text('Select Class'),
                value: selectedClassId,
                items: classes
                    .map((cls) => DropdownMenuItem(
                          value: cls.id,
                          child: Text('${cls.subject} (Grade ${cls.grade})'),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => selectedClassId = value);
                  if (value != null) {
                    _loadLearners(value).then((learners) {
                      setState(() => this.learners = learners);
                    });
                  }
                },
              ),
              if (learners.isNotEmpty)
                ElevatedButton(
                  onPressed: () async {
                    final result = await showDialog<List<String>>(
                      context: context,
                      builder: (context) =>
                          LearnerSelectionDialog(learners: learners),
                    );
                    if (result != null)
                      setState(() => selectedLearnerIds = result);
                  },
                  child: Text('Select Learners (${selectedLearnerIds.length})'),
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
                if (selectedClassId != null && selectedLearnerIds.isNotEmpty) {
                  final timeSlot =
                      '${selectedDay.toIso8601String().split('T')[0]} ${timeSlots[slotIndex]}';
                  final timetableId = const Uuid().v4();
                  final slots = [
                    {
                      'id': const Uuid().v4(),
                      'classId': selectedClassId,
                      'timeSlot': timeSlot,
                      'learnerIds': selectedLearnerIds,
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
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Timetable slot added successfully')));
                  } catch (e) {
                    if (mounted)
                      setState(() =>
                          errorMessage = 'Error adding timetable slot: $e');
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddClassDialog(BuildContext context) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    String? subject;
    String? grade;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              hint: const Text('Select Subject'),
              value: subject,
              items: ['Math', 'Science', 'English']
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => subject = value),
            ),
            DropdownButton<String>(
              hint: const Text('Select Grade'),
              value: grade,
              items: ['10', '11', '12']
                  .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text('Grade $g'),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => grade = value),
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
              if (subject != null && grade != null) {
                final existingClasses =
                    await db.getTeacherClassDataByTeacherId(userId);
                final sameSubjectGradeClasses = existingClasses
                    .where(
                        (cls) => cls.subject == subject && cls.grade == grade)
                    .toList();
                int classNumber = sameSubjectGradeClasses.isEmpty
                    ? 1
                    : sameSubjectGradeClasses.map((cls) {
                          final match =
                              RegExp(r'Class (\d+)$').firstMatch(cls.title);
                          return match != null ? int.parse(match.group(1)!) : 0;
                        }).reduce((a, b) => a > b ? a : b) +
                        1;
                final classTitle = '$subject $grade Class $classNumber';
                final newClass = ClassData(
                  id: const Uuid().v4(),
                  teacherId: userId,
                  subject: subject!,
                  grade: grade!,
                  title: classTitle,
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                );
                try {
                  await db.insertClassData(newClass);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Class added successfully')));
                } catch (e) {
                  if (mounted)
                    setState(() => errorMessage = 'Error adding class: $e');
                }
              }
            },
            child: const Text('Add Class'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddLearnerDialog(BuildContext context) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final learnerNameController = TextEditingController();
    String? grade;
    String? classId;
    final classes = await db.getTeacherClassDataByTeacherId(userId);

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
              value: grade,
              items: ['10', '11', '12']
                  .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text('Grade $g'),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => grade = value),
            ),
            if (classes.isNotEmpty)
              DropdownButton<String>(
                hint: const Text('Select Class (Optional)'),
                value: classId,
                items: classes
                    .map((cls) => DropdownMenuItem(
                          value: cls.id,
                          child: Text(cls.title),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => classId = value),
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
              if (learnerNameController.text.isNotEmpty && grade != null) {
                final newUser = User(
                  id: const Uuid().v4(),
                  country: '', // Placeholder
                  citizenshipId: '', // Placeholder
                  name: learnerNameController.text,
                  surname: '', // Placeholder
                  role: 'learner',
                  roleData: {'grade': grade!},
                );
                try {
                  await db.insertUserData(newUser);
                  if (classId != null) {
                    final classData = await db.getClassDataById(classId!);
                    final updatedLearnerIds = [
                      ...classData.learnerIds,
                      newUser.id
                    ];
                    await db.updateClassLearnerIds(classId!,
                        updatedLearnerIds.toSet().toList()); // Avoid duplicates
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Learner registered successfully')));
                } catch (e) {
                  if (mounted)
                    setState(
                        () => errorMessage = 'Error registering learner: $e');
                }
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
            .where((u) => u.role == 'learner')
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
      builder: (context) => AlertDialog(
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
              onChanged: (value) => setState(() => assessmentType = value),
            ),
            if (assessmentType == 'test' || assessmentType == 'exam')
              TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Timer (seconds)'),
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
            onPressed: () async {
              if (assessmentType != null) {
                closeTime = timerSeconds != null
                    ? DateTime.now().add(Duration(seconds: timerSeconds!))
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
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Assessment added successfully')));
                } catch (e) {
                  if (mounted) {
                    setState(
                        () => errorMessage = 'Error adding assessment: $e');
                  }
                }
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
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

    // Fetch the correct slotId from TimetableSlot associated with the timetable
    String? slotId;
    final slots = await db.getTimetableSlotsByTimetableId(timetable.id);
    if (slots.isNotEmpty) {
      slotId = slots.first.id; // Use the first slot's ID
    } else {
      slotId =
          answer.slotId ?? const Uuid().v4(); // Fallback to existing or new
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
                  selectedDay = DateTime.now(); // Reset to today
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
              if (selected != null)
                setState(() {
                  selectedDay = selected;
                  _loadTimetableSlots();
                });
            },
          ),
          if (role == 'teacher')
            IconButton(
              icon: const Icon(Icons.class_),
              onPressed: () => _showAddClassDialog(context),
              tooltip: 'Add Class',
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: timeSlots.length,
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
                          : null,
                      child: Card(
                        color: slot.isNotEmpty
                            ? _getSubjectColor(slot['subject'] ?? 'Unknown')
                            : Colors.green[100],
                        child: FutureBuilder<int>(
                          future: slot.isNotEmpty && slot['classId'] != null
                              ? Provider.of<DatabaseService>(context,
                                      listen: false)
                                  .getClassDataById(slot['classId'])
                                  .then((data) => data.learnerIds.length)
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
                                        Text(
                                            'Selected: ${slot['learnerIds'] is String ? (slot['learnerIds'] as String).split(',').join(', ') : (slot['learnerIds'] as List<String>).join(', ')}'),
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
                                              if (value == 'add_assessment') {
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
                                                child: Text('Add Assessment'),
                                              ),
                                              const PopupMenuItem(
                                                value: 'open_notes',
                                                child: Text('Open Notes'),
                                              ),
                                              const PopupMenuItem(
                                                value: 'post_question',
                                                child: Text('Post Question'),
                                              ),
                                              const PopupMenuItem(
                                                value: 'select_learner',
                                                child: Text('Select Learner'),
                                              ),
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
      floatingActionButton: role == 'teacher'
          ? FloatingActionButton(
              onPressed: () {
                _showAddTimetableDialog(
                    context, 0); // Default to first slot for FAB
              },
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

  LearnerSelectionDialog({required this.learners});

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
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: widget.learners.length,
          itemBuilder: (context, index) {
            final learner = widget.learners[index];
            return CheckboxListTile(
              title: Text(learner.name),
              value: selectedLearnerIds.contains(learner.id),
              onChanged: (value) {
                setState(() {
                  if (value!)
                    selectedLearnerIds.add(learner.id);
                  else
                    selectedLearnerIds.remove(learner.id);
                });
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
        TextButton(
          onPressed: () => Navigator.pop(context, selectedLearnerIds),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
