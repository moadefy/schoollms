import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:schoollms/services/database_service.dart';
import 'package:schoollms/models/class.dart';
import 'package:schoollms/models/learner.dart';
import 'package:schoollms/models/timetable.dart';
import 'package:schoollms/models/assessment.dart';
import 'package:schoollms/models/question.dart';
import 'package:schoollms/models/answer.dart';
import 'package:schoollms/models/asset.dart';
import 'package:schoollms/models/analytics.dart';
import 'package:schoollms/models/learnertimetable.dart';
import 'package:schoollms/widgets/canvas_widget.dart';
import 'package:device_info_plus/device_info_plus.dart';

class TeacherTimetableScreen extends StatefulWidget {
  final String teacherId;

  TeacherTimetableScreen({required this.teacherId});

  @override
  _TeacherTimetableScreenState createState() => _TeacherTimetableScreenState();
}

class _TeacherTimetableScreenState extends State<TeacherTimetableScreen> {
  late List<Class> _classes;
  late List<Learner> _learners;
  late List<Timetable> _timetables;
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_deviceId == null) {
      _loadInitialData();
    }
  }

  @override
  void initState() {
    super.initState();
    _classes = [];
    _learners = [];
    _timetables = [];
    _selectedDay = DateTime.now();
    _deviceId = null;
    _isLoading = true;
    _errorMessage = null;
  }

  Future<void> _loadInitialData() async {
    try {
      await _initializeDeviceId();
      await _loadClasses();
      await _loadTimetables();
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

  Future<void> _loadClasses() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      final classes = await db.getClassesByTeacher(widget.teacherId);
      if (mounted) {
        setState(() => _classes = classes);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error loading classes: $e');
      }
    }
  }

  Future<void> _loadTimetables() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      print('Loading timetables for teacher ${widget.teacherId}');
      final timetables = await db.getTimetables('');
      final teacherTimetables =
          timetables.where((t) => t.teacherId == widget.teacherId).toList();
      print(
          'Raw timetables count: ${timetables.length}, filtered: ${teacherTimetables.length}');
      if (mounted) {
        setState(() {
          _timetables = teacherTimetables
              .where((t) => t.timeSlot
                  .startsWith(_selectedDay.toIso8601String().split('T')[0]))
              .toList();
          print(
              'Filtered timetables for ${_selectedDay.toIso8601String().split('T')[0]}: ${_timetables.length}');
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error loading timetables: $e');
      }
    }
  }

  Future<void> _showAddTimetableDialog(
      BuildContext context, int slotIndex) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    Class? selectedClass;
    List<String> selectedLearnerIds = [];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Add Timetable Slot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<Class>(
                hint: Text('Select Class'),
                value: selectedClass,
                items: _classes
                    .map((cls) => DropdownMenuItem(
                          value: cls,
                          child: Text('${cls.subject} (Grade ${cls.grade})'),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedClass = value;
                    if (value != null) {
                      _loadLearners(value.grade).then((learners) {
                        setState(() => _learners = learners);
                      });
                    }
                  });
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
                if (selectedClass != null && selectedLearnerIds.isNotEmpty) {
                  final timeSlot =
                      '${_selectedDay.toIso8601String().split('T')[0]} ${_timeSlots[slotIndex]}';
                  final timetable = Timetable(
                    id: Uuid().v4(),
                    teacherId: widget.teacherId,
                    classId: selectedClass!.id,
                    timeSlot: timeSlot,
                    learnerIds: selectedLearnerIds,
                  );
                  try {
                    print('Attempting to insert timetable: $timetable');
                    await db.insertTimetable(timetable);
                    print('Timetable inserted with id: ${timetable.id}');
                    await _loadTimetables(); // Reload to ensure latest data
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Timetable added successfully')),
                    );
                  } catch (e) {
                    print('Error inserting timetable: $e');
                    if (mounted) {
                      setState(
                          () => _errorMessage = 'Error adding timetable: $e');
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

  Future<void> _showAddAssessmentDialog(
      BuildContext context, Timetable timetable) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    String? assessmentType = 'activity';
    int? timerSeconds;
    DateTime? closeTime;

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
                  classIds: [timetable.classId],
                  type: assessmentType!,
                  timerSeconds: timerSeconds,
                  closeTime: closeTime,
                  questionIds: [],
                );
                try {
                  await db.insertAssessment(assessment);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Assessment added successfully')),
                  );
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

  Future<List<Learner>> _loadLearners(String grade) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      return await db.getLearnersByGrade(grade);
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error loading learners: $e');
      }
      return [];
    }
  }

  Future<void> _openLearnerAssessmentCanvas(
      Timetable timetable, String learnerId) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      final assessments = await db.getAssessmentsByClass(timetable.classId);
      if (assessments.isEmpty) return;

      final questions = await db.getQuestionsByClass(timetable.classId);
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
                      remarks: '')))))));

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
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error loading assessment: $e');
      }
    }
  }

  Future<void> _markAnswer(Timetable timetable, Answer answer) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    var strokes = jsonEncode(answer.strokes);
    final assets = await db.getAssetsByLearner(answer.learnerId!);
    DateTime startTime = DateTime.now();

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
                  try {
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Answer marked')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      setState(
                          () => _errorMessage = 'Error marking answer: $e');
                    }
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
            onSave: () {
              strokes = jsonEncode(answer.strokes);
            },
            onUpdate: (data) {
              strokes = jsonEncode(data['strokes']);
            },
            onAssetsUpdate: (updatedAssets) async {
              final db = Provider.of<DatabaseService>(context, listen: false);
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
          ),
        ),
      ),
    );
  }

  Future<double?> _selectScore(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter Score'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: '0-100'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.pop(context, double.tryParse(controller.text) ?? 0.0),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<String?> _selectRemarks(BuildContext context) async {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Enter Remarks'),
        content: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Remarks')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _openTeacherNotesCanvas(Timetable timetable) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      var notesQuestion = await db
          .getQuestionsByClass(timetable.classId)
          .then((questions) => questions.firstWhere(
                (q) =>
                    jsonDecode(q.content)['type'] == 'notes' &&
                    q.classId == timetable.classId,
                orElse: () => Question(
                  id: Uuid().v4(),
                  classId: timetable.classId,
                  content: jsonEncode({'strokes': [], 'type': 'notes'}),
                  pdfPage: null,
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
                    try {
                      DateTime endTime = DateTime.now();
                      int timeSpent = endTime.difference(startTime).inSeconds;
                      final updatedQuestion = Question(
                        id: notesQuestion.id,
                        classId: notesQuestion.classId,
                        content: content,
                        pdfPage: notesQuestion.pdfPage,
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Notes saved')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(
                            () => _errorMessage = 'Error saving notes: $e');
                      }
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
              onSave: () {
                content = jsonEncode(jsonDecode(content));
              },
              onUpdate: (data) {
                content = jsonEncode(data['strokes']);
              },
              onAssetsUpdate: (updatedAssets) async {
                final db = Provider.of<DatabaseService>(context, listen: false);
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
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error loading notes: $e');
      }
    }
  }

  Future<void> _postLearnerQuestion(Timetable timetable) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      var question = Question(
        id: Uuid().v4(),
        classId: timetable.classId,
        content: jsonEncode({'strokes': [], 'type': 'learner_question'}),
        pdfPage: null,
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
                    try {
                      DateTime endTime = DateTime.now();
                      int timeSpent = endTime.difference(startTime).inSeconds;
                      final updatedQuestion = Question(
                        id: question.id,
                        classId: question.classId,
                        content: content,
                        pdfPage: question.pdfPage,
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
                          SnackBar(content: Text('Question posted')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(
                            () => _errorMessage = 'Error posting question: $e');
                      }
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
              onSave: () {
                content = jsonEncode(jsonDecode(content));
              },
              onUpdate: (data) {
                content = jsonEncode(data['strokes']);
              },
              onAssetsUpdate: (updatedAssets) async {
                final db = Provider.of<DatabaseService>(context, listen: false);
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
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error loading question canvas: $e');
      }
    }
  }

  Future<void> _answerLearnerQuestion(
      Timetable timetable, Question question) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      var updatedQuestion = Question(
        id: question.id,
        classId: question.classId,
        content: question.content,
        pdfPage: question.pdfPage,
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
                    try {
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
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Answer posted')),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        setState(() =>
                            _errorMessage = 'Error answering question: $e');
                      }
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
              onSave: () {
                content = jsonEncode(jsonDecode(content));
              },
              onUpdate: (data) {
                content = jsonEncode(data['strokes']);
              },
              onAssetsUpdate: (updatedAssets) async {
                final db = Provider.of<DatabaseService>(context, listen: false);
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
            ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error loading answer canvas: $e');
      }
    }
  }

  Future<void> _showLearnerSelectionDialog(Timetable timetable) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      final classId = timetable.classId;
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
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error loading learner selection: $e');
      }
    }
  }

  Future<void> _loadSlotDetails(Timetable timetable) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      final learnerTimetables = await db.getLearnerTimetable(
          timetable.learnerIds.isNotEmpty ? timetable.learnerIds[0] : '');
      final assessments = await db.getAssessmentsByClass(timetable.classId);
      final cardIndex = _timetables.indexWhere((t) => t.id == timetable.id);
      if (cardIndex != -1) {
        final cardState =
            context.findAncestorStateOfType<_TimetableCardState>();
        if (cardState != null) {
          cardState.updateDetails(learnerTimetables, assessments);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Error loading slot details: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Teacher Timetable'),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: _selectedDay,
                firstDate: DateTime(2023),
                lastDate: DateTime(2030),
              );
              if (selected != null) {
                setState(() {
                  _selectedDay = selected;
                  _loadTimetables();
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
              : MultiProvider(
                  providers: [
                    Provider<List<Class>>.value(value: _classes),
                  ],
                  child: GridView.builder(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 1,
                      childAspectRatio: 4,
                    ),
                    itemCount: _timeSlots.length,
                    itemBuilder: (context, index) {
                      final fullTimeSlot =
                          '${_selectedDay.toIso8601String().split('T')[0]} ${_timeSlots[index]}';
                      final timetable = _timetables.firstWhere(
                        (t) => t.timeSlot == fullTimeSlot,
                        orElse: () => Timetable(
                            id: Uuid().v4(),
                            teacherId: '',
                            classId: '',
                            timeSlot: fullTimeSlot,
                            learnerIds: []),
                      );

                      if (timetable.classId.isEmpty) {
                        return GestureDetector(
                          onTap: () => _showAddTimetableDialog(context, index),
                          child: AnimatedContainer(
                            duration: Duration(milliseconds: 300),
                            color: Colors.green[100],
                            child: Center(
                              child: Text(_timeSlots[index],
                                  style: TextStyle(color: Colors.grey)),
                            ),
                          ),
                        );
                      } else {
                        return Draggable<Timetable>(
                          data: timetable,
                          feedback: Material(
                            child: Container(
                              width: 200,
                              height: 50,
                              child: TimetableCard(
                                key: ValueKey(timetable.id),
                                timetable: timetable,
                                onLoadDetails: () =>
                                    _loadSlotDetails(timetable),
                                deviceId: _deviceId,
                                onOpenAssessment: (t, l) =>
                                    _openLearnerAssessmentCanvas(t, l),
                              ),
                            ),
                          ),
                          child: DragTarget<Timetable>(
                            builder: (context, candidateData, rejectedData) {
                              return GestureDetector(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    builder: (context) => Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        ListTile(
                                          leading: Icon(Icons.add),
                                          title: Text('Add Assessment'),
                                          onTap: () => _showAddAssessmentDialog(
                                              context, timetable),
                                        ),
                                        ListTile(
                                          leading: Icon(Icons.edit),
                                          title: Text('Add Teacher Notes'),
                                          onTap: () => _openTeacherNotesCanvas(
                                              timetable),
                                        ),
                                        ListTile(
                                          leading: Icon(Icons.question_answer),
                                          title: Text('Post Learner Question'),
                                          onTap: () =>
                                              _postLearnerQuestion(timetable),
                                        ),
                                        ListTile(
                                          leading: Icon(Icons.person),
                                          title:
                                              Text('View Learner Assessments'),
                                          onTap: () =>
                                              _showLearnerSelectionDialog(
                                                  timetable),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                                child: Container(
                                  color: candidateData.isNotEmpty
                                      ? Colors.blue[100]
                                      : null,
                                  child: TimetableCard(
                                    key: ValueKey(timetable.id),
                                    timetable: timetable,
                                    onLoadDetails: () =>
                                        _loadSlotDetails(timetable),
                                    deviceId: _deviceId,
                                    onOpenAssessment: (t, l) =>
                                        _openLearnerAssessmentCanvas(t, l),
                                  ),
                                ),
                              );
                            },
                            onWillAccept: (data) =>
                                data != null && data.id != timetable.id,
                            onAccept: (data) async {
                              final db = Provider.of<DatabaseService>(context,
                                  listen: false);
                              try {
                                final newIndex = _timeSlots
                                    .indexOf(timetable.timeSlot.split(' ')[1]);
                                final oldIndex = _timeSlots
                                    .indexOf(data.timeSlot.split(' ')[1]);
                                if (newIndex != -1 && oldIndex != -1) {
                                  final updatedTimetable = Timetable(
                                    id: data.id,
                                    teacherId: data.teacherId,
                                    classId: data.classId,
                                    timeSlot:
                                        '${_selectedDay.toIso8601String().split('T')[0]} ${_timeSlots[newIndex]}',
                                    learnerIds: data.learnerIds,
                                  );
                                  await db.insertTimetable(updatedTimetable);
                                  if (mounted) {
                                    setState(() {
                                      _timetables.remove(data);
                                      _timetables.add(updatedTimetable);
                                    });
                                  }
                                  if (_deviceId != null) {
                                    DateTime endTime = DateTime.now();
                                    final analytics = Analytics(
                                      questionId: '',
                                      learnerId: widget.teacherId,
                                      timeSpentSeconds: 0,
                                      submissionStatus: 'updated',
                                      deviceId: _deviceId!,
                                      timestamp: endTime.millisecondsSinceEpoch,
                                    );
                                    await db.insertAnalytics(analytics);
                                  }
                                }
                              } catch (e) {
                                if (mounted) {
                                  setState(() => _errorMessage =
                                      'Error updating timetable: $e');
                                }
                              }
                            },
                          ),
                        );
                      }
                    },
                  ),
                ),
    );
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
                      remarks: '')))))));
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
    final classData = context.read<List<Class>>().firstWhere(
          (cls) => cls.id == widget.timetable.classId,
          orElse: () => Class(
              id: '', teacherId: '', subject: 'Unknown', grade: 'Unknown'),
        );
    return Card(
      margin: EdgeInsets.all(4.0),
      child: Padding(
        padding: EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Time: ${widget.timetable.timeSlot.split(' ')[1]}',
                style: TextStyle(fontWeight: FontWeight.bold)),
            Text('Class: ${classData.subject} (Grade ${classData.grade})'),
            Text('Learners: ${widget.timetable.learnerIds.length}'),
            SizedBox(height: 8.0),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _learnerTimetables.length,
                itemBuilder: (context, index) {
                  final lt = _learnerTimetables[index];
                  final stats = _learnerStats[lt.learnerId] ?? {};
                  return ListTile(
                    title: Text('Learner ${lt.learnerId}'),
                    subtitle: Text(
                      'Status: ${stats['status']}, Attendance: ${stats['attendance']}, '
                      'Accessed: ${stats['accessed']}, Completed: ${stats['completed']}, '
                      'Score: ${stats['overallScore']?.toStringAsFixed(2) ?? '0.00'}',
                    ),
                    onTap: () =>
                        widget.onOpenAssessment(widget.timetable, lt.learnerId),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
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
