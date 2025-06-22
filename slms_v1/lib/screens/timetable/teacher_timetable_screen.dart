import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:schoollms/services/database_service.dart';
import 'package:schoollms/models/class.dart';
import 'package:schoollms/models/learner.dart';
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

class TeacherTimetableScreen extends StatefulWidget {
  final String teacherId;

  TeacherTimetableScreen({required this.teacherId});

  @override
  _TeacherTimetableScreenState createState() => _TeacherTimetableScreenState();
}

class _TeacherTimetableScreenState extends State<TeacherTimetableScreen> {
  late List<Map<String, dynamic>> _timetableSlots;
  late List<Learner> _learners; // For learner selection
  final List<String> _timeSlots = [
    '09:00-10:00',
    '10:00-11:00',
    '11:00-12:00',
    '12:00-13:00',
    '13:00-14:00',
  ];
  late DateTime _selectedDay;
  String? _deviceId;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _timetableSlots = [];
    _learners = []; // Initialize empty list
    _selectedDay = DateTime.now();
    _deviceId = null;
    _isLoading = true;
    _errorMessage = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_deviceId == null) {
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    try {
      await _initializeDeviceId();
      await _loadTimetableSlots();
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error loading data: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _initializeDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Theme.of(context).platform == TargetPlatform.android) {
      final androidInfo = await deviceInfo.androidInfo;
      if (mounted) {
        setState(() => _deviceId = androidInfo.id);
      }
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      final iosInfo = await deviceInfo.iosInfo;
      if (mounted) {
        setState(() => _deviceId = iosInfo.identifierForVendor);
      }
    } else {
      if (mounted) {
        setState(() => _deviceId = 'teacher_device_${widget.teacherId}');
      }
    }
  }

  Future<void> _loadTimetableSlots() async {
    setState(() => _isLoading = true);
    try {
      final db = Provider.of<DatabaseService>(context, listen: false);
      final slots = await db.getTeacherTimetableSlots(widget.teacherId);
      setState(() {
        _timetableSlots = slots;
        _isLoading = false;
        if (slots.isEmpty) {
          _errorMessage =
              'No timetables found. Add a new timetable to get started.';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading timetable slots: $e';
      });
    }
  }

  Future<void> _showAddTimetableDialog(
      BuildContext context, int slotIndex) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final classes = await db.getClassesByTeacher(widget.teacherId);
    String? selectedClassId;
    List<String> selectedLearnerIds = [];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add Timetable Slot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                hint: Text('Select Class'),
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
                      setState(() => _learners = learners);
                    });
                  }
                },
              ),
              if (_learners.isNotEmpty)
                ElevatedButton(
                  onPressed: () async {
                    final result = await showDialog<List<String>>(
                      context: context,
                      builder: (context) =>
                          LearnerSelectionDialog(learners: _learners),
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
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (selectedClassId != null && selectedLearnerIds.isNotEmpty) {
                  final timeSlot =
                      '${_selectedDay.toIso8601String().split('T')[0]} ${_timeSlots[slotIndex]}';
                  final timetableId = Uuid().v4();
                  final slots = [
                    {
                      'id': Uuid().v4(),
                      'classId': selectedClassId,
                      'timeSlot': timeSlot,
                      'learnerIds': selectedLearnerIds,
                    },
                  ];
                  final timetable = Timetable(
                    id: timetableId,
                    teacherId: widget.teacherId,
                    userRole: 'teacher',
                    userId: widget.teacherId,
                  );
                  try {
                    await db.insertTimetable(timetable, slots);
                    await _loadTimetableSlots();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Timetable slot added successfully')));
                  } catch (e) {
                    if (mounted) {
                      setState(() =>
                          _errorMessage = 'Error adding timetable slot: $e');
                    }
                  }
                }
              },
              child: Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<Learner>> _loadLearners(String classId) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      final classData = await db.getClassById(classId);
      return classData != null
          ? await db.getLearnersByGrade(classData['grade'] as String)
          : [];
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error loading learners: $e');
      }
      return [];
    }
  }

  Future<void> _loadSlotDetails() async {
    final db = Provider.of<DatabaseService>(context, listen: false);

    // Use the first slot association or learner from the current teacher's timetable slots
    final slotAssociation = _timetableSlots.isNotEmpty
        ? _timetableSlots
            .firstWhere((slot) => slot['slot_id'] != null,
                orElse: () => {})['learnerIds']
            ?.first
        : null;
    final learnerId = slotAssociation ??
        widget.teacherId; // Fallback to teacherId if no learners
    final learnerTimetables =
        await db.getLearnerTimetable(learnerId, sinceTimestamp: 0);

    // Fetch classId from the first available timetable slot
    String? classId;
    if (_timetableSlots.isNotEmpty) {
      classId = _timetableSlots.first['classId'];
    } else {
      if (mounted) {
        setState(() =>
            _errorMessage = 'No slots found for teacher ${widget.teacherId}');
      }
      return; // Exit early if no slots
    }

    final assessments = await db.getAssessmentsByClass(classId!);
    final cardState = context.findAncestorStateOfType<_TimetableCardState>();
    if (cardState != null) {
      cardState.updateDetails(learnerTimetables, assessments);
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
            _errorMessage = 'No slot or class associated with this timetable');
      }
      return;
    }

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Assessment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              hint: Text('Select Assessment Type'),
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
                decoration: InputDecoration(labelText: 'Timer (seconds)'),
                onChanged: (value) => timerSeconds = int.tryParse(value),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (assessmentType != null) {
                closeTime = timerSeconds != null
                    ? DateTime.now().add(Duration(seconds: timerSeconds!))
                    : null;
                final assessment = Assessment(
                  id: Uuid().v4(),
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
                      SnackBar(content: Text('Assessment added successfully')));
                } catch (e) {
                  if (mounted) {
                    setState(
                        () => _errorMessage = 'Error adding assessment: $e');
                  }
                }
                Navigator.pop(context);
              }
            },
            child: Text('Save'),
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
                    id: Uuid().v4(),
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
      // Handle case where no slots are found (e.g., set a default or log error)
      slotId = answer.slotId ??
          Uuid().v4(); // Fallback to existing slotId or generate new
      if (mounted) {
        setState(() => _errorMessage =
            'No slots found for timetable ${timetable.id}, using fallback slotId');
      }
    }

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Mark Answer'),
            actions: [
              IconButton(
                icon: Icon(Icons.save),
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
                    slotId: slotId, // Use the fetched or fallback slotId
                  );
                  await db.insertAnswer(updatedAnswer);
                  final analytics = Analytics(
                    questionId: answer.questionId,
                    learnerId: answer.learnerId!,
                    timeSpentSeconds: timeSpent,
                    submissionStatus: 'marked',
                    deviceId: _deviceId!,
                    timestamp: endTime.millisecondsSinceEpoch,
                  );
                  await db.insertAnalytics(analytics);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Answer marked')));
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
                  id: Uuid().v4(),
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
            slotId: slotId, // Use the fetched or fallback slotId
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
                id: Uuid().v4(),
                classId: classId!,
                content: jsonEncode({'strokes': [], 'type': 'notes'}),
                pdfPage: null,
                slotId: slotId,
              ),
            ));
    var content = notesQuestion.content;
    final assets = await db.getAssetsByLearner(widget.teacherId);
    DateTime startTime = DateTime.now();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Teacher Notes'),
            actions: [
              IconButton(
                icon: Icon(Icons.save),
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
                    learnerId: widget.teacherId,
                    timeSpentSeconds: timeSpent,
                    submissionStatus: 'saved',
                    deviceId: _deviceId!,
                    timestamp: endTime.millisecondsSinceEpoch,
                  );
                  await db.insertAnalytics(analytics);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Notes saved')));
                  }
                },
              ),
            ],
          ),
          body: CanvasWidget(
            learnerId: widget.teacherId,
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
                  id: Uuid().v4(),
                  learnerId: widget.teacherId,
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
      id: Uuid().v4(),
      classId: classId,
      content: jsonEncode({'strokes': [], 'type': 'learner_question'}),
      pdfPage: null,
      slotId: slotId,
    );
    var content = question.content;
    final assets = await db.getAssetsByLearner(widget.teacherId);
    DateTime startTime = DateTime.now();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Post Learner Question'),
            actions: [
              IconButton(
                icon: Icon(Icons.send),
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
                    learnerId: widget.teacherId,
                    timeSpentSeconds: timeSpent,
                    submissionStatus: 'posted',
                    deviceId: _deviceId!,
                    timestamp: endTime.millisecondsSinceEpoch,
                  );
                  await db.insertAnalytics(analytics);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Question posted')));
                  }
                },
              ),
            ],
          ),
          body: CanvasWidget(
            learnerId: widget.teacherId,
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
                  id: Uuid().v4(),
                  learnerId: widget.teacherId,
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
    final assets = await db.getAssetsByLearner(widget.teacherId);
    DateTime startTime = DateTime.now();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Answer Learner Question'),
            actions: [
              IconButton(
                icon: Icon(Icons.send),
                onPressed: () async {
                  DateTime endTime = DateTime.now();
                  int timeSpent = endTime.difference(startTime).inSeconds;
                  final decodedContent = jsonDecode(content);
                  decodedContent['answered'] = true;
                  updatedQuestion.content = jsonEncode(decodedContent);
                  await db.insertQuestion(updatedQuestion);
                  final analytics = Analytics(
                    questionId: question.id,
                    learnerId: widget.teacherId,
                    timeSpentSeconds: timeSpent,
                    submissionStatus: 'answered',
                    deviceId: _deviceId!,
                    timestamp: endTime.millisecondsSinceEpoch,
                  );
                  await db.insertAnalytics(analytics);
                  if (mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('Answer posted')));
                  }
                },
              ),
            ],
          ),
          body: CanvasWidget(
            learnerId: widget.teacherId,
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
                  id: Uuid().v4(),
                  learnerId: widget.teacherId,
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

    final classData = await db.getClassById(classId);
    if (classData == null) return;
    final grade = classData['grade'] as String;
    final learners = await db.getLearnersByGrade(grade);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Learner'),
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
            child: Text('Cancel'),
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
        title: Text('Select Score'),
        content: TextField(
          keyboardType: TextInputType.number,
          onChanged: (value) => score = double.tryParse(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, score),
            child: Text('OK'),
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
        title: Text('Add Remarks'),
        content: TextField(
          onChanged: (value) => remarks = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, remarks),
            child: Text('OK'),
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
        title: Text('Teacher Timetable'),
        actions: [
          DropdownButton<DateTimeRange>(
            value: _selectedDay != null &&
                    [
                      DateTimeRange(start: DateTime.now(), end: DateTime.now()),
                      DateTimeRange(
                        start: DateTime.now(),
                        end: DateTime.now().add(Duration(days: 6)),
                      ),
                      DateTimeRange(
                        start: DateTime.now(),
                        end: DateTime.now().add(Duration(days: 30)),
                      ),
                    ].any((range) => range.start == _selectedDay)
                ? DateTimeRange(start: _selectedDay!, end: _selectedDay!)
                : null,
            items: [
              DropdownMenuItem(
                value:
                    DateTimeRange(start: DateTime.now(), end: DateTime.now()),
                child: Text('Day'),
              ),
              DropdownMenuItem(
                value: DateTimeRange(
                  start: DateTime.now(),
                  end: DateTime.now().add(Duration(days: 6)),
                ),
                child: Text('Week'),
              ),
              DropdownMenuItem(
                value: DateTimeRange(
                  start: DateTime.now(),
                  end: DateTime.now().add(Duration(days: 30)),
                ),
                child: Text('Month'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedDay = value.start;
                  _loadTimetableSlots();
                });
              }
            },
          ),
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: _selectedDay ?? DateTime.now(),
                firstDate: DateTime(2023),
                lastDate: DateTime(2030),
              );
              if (selected != null) {
                setState(() {
                  _selectedDay = selected;
                  _loadTimetableSlots();
                });
              }
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
              : GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: _timeSlots.length,
                  itemBuilder: (context, index) {
                    final timeSlot = _timeSlots[index];
                    final fullTimeSlot =
                        '${_selectedDay.toIso8601String().split('T')[0]} $timeSlot';
                    final slot = _timetableSlots.firstWhere(
                      (s) => s['timeSlot'] == fullTimeSlot,
                      orElse: () => {},
                    );

                    return GestureDetector(
                      onTap: slot.isEmpty
                          ? () => _showAddTimetableDialog(context, index)
                          : null,
                      child: Card(
                        color: slot.isNotEmpty
                            ? _getSubjectColor(slot['subject'] ?? 'Unknown')
                            : Colors.green[100],
                        child: Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(timeSlot,
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                              if (slot.isNotEmpty)
                                Column(
                                  children: [
                                    Text(
                                        'Subject: ${slot['subject'] ?? 'Unknown'}'),
                                    Text(
                                        'Grade: ${slot['grade'] ?? 'Unknown'}'),
                                    Text(
                                      'Learners: ${slot['learnerIds'] is String ? (slot['learnerIds'] as String).split(',').join(', ') : (slot['learnerIds'] as List<String>).join(', ')}',
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
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

class TimetableCard extends StatefulWidget {
  final Timetable timetable;
  final VoidCallback onLoadDetails;
  final String? deviceId;
  final Function(Timetable, String) onOpenAssessment;

  TimetableCard({
    required this.timetable,
    required this.onLoadDetails,
    this.deviceId,
    required this.onOpenAssessment,
    Key? key,
  }) : super(key: key);

  @override
  _TimetableCardState createState() => _TimetableCardState();

  void updateDetails(
      List<LearnerTimetable> learnerTimetables, List<Assessment> assessments) {
    final state = (_timetableState as _TimetableCardState?);
    if (state != null) {
      state.updateDetails(learnerTimetables, assessments);
    }
  }

  static _TimetableCardState? _timetableState;
}

class _TimetableCardState extends State<TimetableCard> {
  late List<LearnerTimetable> _learnerTimetables;
  late List<Assessment> _assessments;
  late Map<String, Map<String, dynamic>> _learnerStats;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_learnerTimetables.isEmpty || _assessments.isEmpty) {
      widget.onLoadDetails();
      _updateLearnerStats();
    }
  }

  @override
  void initState() {
    super.initState();
    TimetableCard._timetableState = this;
    _learnerTimetables = [];
    _assessments = [];
    _learnerStats = {};
  }

  void updateDetails(
      List<LearnerTimetable> learnerTimetables, List<Assessment> assessments) {
    if (mounted) {
      setState(() {
        _learnerTimetables = learnerTimetables;
        _assessments = assessments;
        _updateLearnerStats();
      });
    }
  }

  Future<void> _updateLearnerStats() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    _learnerStats.clear();
    if (_learnerTimetables.isEmpty || _assessments.isEmpty) return;
    for (var lt in _learnerTimetables) {
      final answers = await Future.wait(_assessments.map((a) => Future.wait(a
          .questionIds
          .map((qId) => db.getAnswersByQuestion(qId).then((answers) =>
              answers.firstWhere((a) => a.learnerId == lt.learnerId,
                  orElse: () => Answer(
                      id: Uuid().v4(),
                      questionId: qId,
                      learnerId: lt.learnerId,
                      strokes: [],
                      assets: [],
                      score: 0.0,
                      remarks: '',
                      slotId: a.slotId)))))));
      bool accessed = answers.any((answerList) =>
          answerList.isNotEmpty && answerList[0].strokes.isNotEmpty);
      bool completed = answers.every(
          (answerList) => answerList.isNotEmpty && answerList[0].score != null);
      double overallScore = answers.isNotEmpty
          ? answers
                  .where((answerList) => answerList.isNotEmpty)
                  .map((answerList) => answerList[0].score ?? 0.0)
                  .reduce((a, b) => a + b) /
              answers.length
          : 0.0;
      _learnerStats[lt.learnerId] = {
        'status': lt.status ?? 'N/A',
        'attendance': lt.attendance ?? 'N/A',
        'accessed': accessed,
        'completed': completed,
        'overallScore': overallScore,
      };
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(); // Placeholder, as this is not directly used in the new grid view
  }
}

class LearnerSelectionDialog extends StatefulWidget {
  final List<Learner> learners;

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
      title: Text('Select Learners'),
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
                  if (value!) {
                    selectedLearnerIds.add(learner.id);
                  } else {
                    selectedLearnerIds.remove(learner.id);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, selectedLearnerIds),
          child: Text('Confirm'),
        ),
      ],
    );
  }
}
