import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:schoollms/services/database_service.dart';
import 'package:schoollms/models/timetable.dart';
import 'package:schoollms/models/class.model.dart';
import 'package:schoollms/models/timetable_slot.dart';
import 'package:schoollms/models/question.dart';
import 'package:schoollms/models/assessment.dart';
import 'package:schoollms/models/answer.dart';
import 'package:schoollms/models/subject.dart';
import 'package:schoollms/models/grade.dart';
import 'package:schoollms/models/asset.dart';
import 'package:schoollms/models/analytics.dart';
import 'package:schoollms/models/user.dart';
import 'package:schoollms/widgets/canvas_widget.dart';
import 'package:device_info_plus/device_info_plus.dart';

class TeacherCanvasScreen extends StatefulWidget {
  final String teacherId;
  final String? timetableId; // Optional parameter for context
  final String? userRole; // Optional parameter for context

  const TeacherCanvasScreen({
    super.key,
    required this.teacherId,
    this.timetableId,
    this.userRole,
  });

  @override
  _TeacherCanvasScreenState createState() => _TeacherCanvasScreenState();
}

class _TeacherCanvasScreenState extends State<TeacherCanvasScreen> {
  List<Timetable> _timetables = [];
  Timetable? _selectedTimetable;
  ClassData? _class;
  List<Question> _questions = [];
  List<Assessment> _assessments = [];
  String _filter = '';
  Assessment? _selectedAssessment;
  String? _deviceId;
  String? _effectiveTimetableId; // To store the resolved timetableId
  String? _effectiveSlotId; // To store the resolved slotId
  Map<String, List<TimetableSlot>> _timetableSlots =
      {}; // Store slots per timetable

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_deviceId == null) {
      _initializeDeviceId();
    }
    if (_timetables.isEmpty) {
      _loadTimetables();
    }
  }

  @override
  void initState() {
    super.initState();
    _deviceId = null; // Initialize with null to trigger initialization
    _timetables = []; // Ensure initial state is empty
  }

  Future<void> _initializeDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Theme.of(context).platform == TargetPlatform.android) {
      final androidInfo = await deviceInfo.androidInfo;
      if (mounted) {
        setState(() {
          _deviceId = androidInfo.id;
        });
      }
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      final iosInfo = await deviceInfo.iosInfo;
      if (mounted) {
        setState(() {
          _deviceId = iosInfo.identifierForVendor;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _deviceId = 'teacher_device_${widget.teacherId}';
        });
      }
    }
  }

  Future<void> _loadTimetables() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      final allTimetables = await db.getTimetables('');
      final teacherTimetables =
          allTimetables.where((t) => t.teacherId == widget.teacherId).toList();
      final slotFutures =
          teacherTimetables.map((t) => db.getTimetableSlotsByTimetableId(t.id));
      final slotLists = await Future.wait(slotFutures);
      final slotMap = Map.fromIterables(
        teacherTimetables.map((t) => t.id),
        slotLists,
      );
      if (mounted) {
        setState(() {
          _timetables = teacherTimetables;
          _selectedTimetable = widget.timetableId != null
              ? teacherTimetables.firstWhere(
                  (t) => t.id == widget.timetableId,
                  orElse: () => teacherTimetables.isNotEmpty
                      ? teacherTimetables[0]
                      : Timetable(
                          id: '', teacherId: '', userId: '', userRole: ''),
                )
              : (teacherTimetables.isNotEmpty ? teacherTimetables[0] : null);
          _timetableSlots = slotMap;
          if (_selectedTimetable != null) {
            _resolveTimetableAndSlotId();
            _loadClassData();
            _loadQuestions();
            _loadAssessments();
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading timetables: $e')),
        );
      }
    }
  }

  Future<void> _resolveTimetableAndSlotId() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      if (widget.timetableId != null) {
        setState(() {
          _effectiveTimetableId = widget.timetableId;
        });
        final slots =
            await db.getTimetableSlotsByTimetableId(widget.timetableId!);
        if (slots.isNotEmpty) {
          setState(() {
            _effectiveSlotId = slots.first.id;
          });
        }
        return;
      }
      if (_selectedTimetable != null) {
        setState(() {
          _effectiveTimetableId = _selectedTimetable!.id;
        });
        final slots = _timetableSlots[_selectedTimetable!.id] ??
            await db.getTimetableSlotsByTimetableId(_selectedTimetable!.id);
        if (slots.isNotEmpty) {
          setState(() {
            _effectiveSlotId = slots.first.id;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error resolving timetable/slot: $e')),
        );
      }
    }
  }

  Future<void> _loadClassData() async {
    if (_selectedTimetable == null || _effectiveSlotId == null) return;
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      final slots = _timetableSlots[_selectedTimetable!.id] ??
          await db.getTimetableSlotsByTimetableId(_selectedTimetable!.id);
      if (slots.isNotEmpty) {
        final classId = slots.first.classId;
        final classData = await db.getClassDataById(classId);
        if (mounted) {
          setState(() {
            _class = classData;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading class data: $e')),
        );
      }
    }
  }

  Future<void> _loadQuestions() async {
    if (_selectedTimetable == null || _effectiveSlotId == null) return;
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      final slots = _timetableSlots[_selectedTimetable!.id] ??
          await db.getTimetableSlotsByTimetableId(_selectedTimetable!.id);
      if (slots.isNotEmpty) {
        final classId = slots.first.classId;
        final questions = await db.getQuestionsByClass(classId);
        if (mounted) {
          setState(() {
            _questions =
                questions.where((q) => q.slotId == _effectiveSlotId).toList();
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading questions: $e')),
        );
      }
    }
  }

  Future<void> _loadAssessments() async {
    if (_selectedTimetable == null || _effectiveSlotId == null) return;
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      final slots = _timetableSlots[_selectedTimetable!.id] ??
          await db.getTimetableSlotsByTimetableId(_selectedTimetable!.id);
      if (slots.isNotEmpty) {
        final classId = slots.first.classId;
        final assessments = await db.getAssessmentsByClass(classId);
        if (mounted) {
          setState(() {
            _assessments = assessments;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading assessments: $e')),
        );
      }
    }
  }

  Future<void> _addQuestion() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    String canvasData = jsonEncode([]);
    final questionId = const Uuid().v4();
    int? pdfPage = null;
    final slots =
        _timetableSlots[_effectiveTimetableId ?? _selectedTimetable!.id] ??
            await db.getTimetableSlotsByTimetableId(
                _effectiveTimetableId ?? _selectedTimetable!.id);
    String? selectedClassId = slots.isNotEmpty ? slots.first.classId : null;
    String? assessmentId = await _selectAssessment(context);
    DateTime startTime = DateTime.now();

    if (assessmentId == null ||
        selectedClassId == null ||
        _deviceId == null ||
        _effectiveSlotId == null) return;

    final assessmentType = await _getAssessmentType(assessmentId);
    int? timerSeconds = (assessmentType == 'test' || assessmentType == 'exam')
        ? await _selectTimerDuration(context)
        : null;
    DateTime? closeTime = timerSeconds != null
        ? DateTime.now().add(Duration(seconds: timerSeconds))
        : null;

    final question = Question(
      id: questionId,
      classId: selectedClassId,
      content: canvasData,
      pdfPage: pdfPage,
      slotId: _effectiveSlotId,
      assessmentId: assessmentId,
      timetableId: _effectiveTimetableId,
    );

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('Draw Question')),
          body: CanvasWidget(
            learnerId: widget.teacherId,
            strokes: canvasData,
            readOnly: false,
            initialAssets: [],
            onSave: () {},
            onUpdate: (data) {
              canvasData = jsonEncode(data['strokes']);
            },
            onAssetsUpdate: (assets) async {
              for (var asset in assets) {
                await db.insertAsset(Asset(
                  id: const Uuid().v4(),
                  learnerId: widget.teacherId,
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
            timetableId: _effectiveTimetableId,
            slotId: _effectiveSlotId,
            userRole: widget.userRole ?? 'teacher',
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              if (!mounted) return;
              try {
                DateTime endTime = DateTime.now();
                int timeSpent = endTime.difference(startTime).inSeconds;
                await db.insertQuestion(question);
                if (mounted) {
                  setState(() {
                    _questions.add(question);
                  });
                  final analytics = Analytics(
                    questionId: questionId,
                    learnerId: widget.teacherId,
                    timeSpentSeconds: timeSpent,
                    submissionStatus: 'submitted',
                    deviceId: _deviceId!,
                    timestamp: endTime.millisecondsSinceEpoch,
                    timetableId: _effectiveTimetableId,
                    slotId: _effectiveSlotId,
                  );
                  await db.insertAnalytics(analytics);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Question saved')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: const Icon(Icons.save),
          ),
        ),
      ),
    );
  }

  Future<String?> _selectAssessment(BuildContext context) async {
    if (_assessments.isEmpty) return null;
    return showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Assessment'),
        children: _assessments
            .map((assessment) => SimpleDialogOption(
                  child: Text(assessment.type),
                  onPressed: () {
                    setState(() {
                      _selectedAssessment = assessment;
                    });
                    Navigator.pop(context, assessment.id);
                  },
                ))
            .toList(),
      ),
    );
  }

  Future<String> _getAssessmentType(String assessmentId) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final assessment = _assessments.firstWhere(
      (a) => a.id == assessmentId,
      orElse: () => throw Exception('Assessment not found'),
    );
    return assessment.type;
  }

  Future<int?> _selectTimerDuration(BuildContext context) async {
    int? duration;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Set Timer Duration (seconds)'),
        content: TextField(
          keyboardType: TextInputType.number,
          onChanged: (value) => duration = int.tryParse(value),
          decoration: const InputDecoration(hintText: 'Enter seconds'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, duration ?? 300),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return duration;
  }

  Future<void> _viewQuestion(Question question) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      final assets = await db.getAssetsByLearner(widget.teacherId);
      DateTime startTime = DateTime.now();
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
                title: Text(
                    'Question${question.pdfPage != null ? " (PDF Page ${question.pdfPage})" : ""}')),
            body: CanvasWidget(
              learnerId: widget.teacherId,
              strokes: question.content,
              readOnly: true,
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
              onSave: () {},
              onUpdate: (data) {},
              timetableId: _effectiveTimetableId,
              slotId: question.slotId,
              userRole: widget.userRole ?? 'teacher',
            ),
          ),
        ),
      );
      if (mounted) {
        final endTime = DateTime.now();
        final timeSpent = endTime.difference(startTime).inSeconds;
        final analytics = Analytics(
          questionId: question.id,
          learnerId: widget.teacherId,
          timeSpentSeconds: timeSpent,
          submissionStatus: 'viewed',
          deviceId: _deviceId ?? 'teacher_device_${widget.teacherId}',
          timestamp: endTime.millisecondsSinceEpoch,
          timetableId: _effectiveTimetableId,
          slotId: question.slotId,
        );
        await db.insertAnalytics(analytics);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error viewing question: $e')),
        );
      }
    }
  }

  Future<void> _markAnswers(Question question) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      final answers = await db.getAnswersByQuestion(question.id);
      final slots =
          _timetableSlots[_effectiveTimetableId ?? _selectedTimetable!.id] ??
              await db.getTimetableSlotsByTimetableId(
                  _effectiveTimetableId ?? _selectedTimetable!.id);
      if (slots.isEmpty) return;
      final classId = slots.first.classId;
      final classData = await db.getClassDataById(classId);
      if (classData == null) return;
      final learners = await getUsersByClassId(context, classId);

      for (var answer in answers) {
        if (!learners.any((l) => l.id == answer.learnerId)) continue;
        String updatedStrokes = jsonEncode(answer.strokes);
        final answerAssets = await db.getAssetsByLearner(answer.learnerId);
        DateTime startTime = DateTime.now();

        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text('Mark Answer by ${answer.learnerId}'),
                actions: [
                  IconButton(
                    icon: const Icon(Icons.save),
                    onPressed: () async {
                      if (!mounted) return;
                      try {
                        DateTime endTime = DateTime.now();
                        int timeSpent = endTime.difference(startTime).inSeconds;
                        final updatedAnswer = Answer(
                          id: answer.id,
                          questionId: answer.questionId,
                          learnerId: answer.learnerId,
                          strokes: jsonDecode(updatedStrokes),
                          assets: answer.assets,
                          score: await _selectScore(context) ?? answer.score,
                          remarks:
                              await _selectRemarks(context) ?? answer.remarks,
                          slotId: question.slotId,
                        );
                        await db.insertAnswer(updatedAnswer);
                        final analytics = Analytics(
                          questionId: question.id,
                          learnerId: answer.learnerId,
                          timeSpentSeconds: timeSpent,
                          submissionStatus: 'marked',
                          deviceId:
                              _deviceId ?? 'teacher_device_${widget.teacherId}',
                          timestamp: endTime.millisecondsSinceEpoch,
                          timetableId: _effectiveTimetableId,
                          slotId: question.slotId,
                        );
                        await db.insertAnalytics(analytics);
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Answer marked')),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e')),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
              body: CanvasWidget(
                learnerId: answer.learnerId,
                strokes: updatedStrokes,
                readOnly: false,
                initialAssets: answerAssets
                    .map((a) => CanvasAsset(
                          id: a.id,
                          type: a.type,
                          path: a.data,
                          pageIndex: 0,
                          position: Offset(a.positionX, a.positionY),
                          scale: a.scale,
                        ))
                    .toList(),
                onSave: () {},
                onUpdate: (data) {
                  updatedStrokes = jsonEncode(data['strokes']);
                },
                onAssetsUpdate: (assets) async {
                  for (var asset in assets) {
                    await db.insertAsset(Asset(
                      id: const Uuid().v4(),
                      learnerId: answer.learnerId,
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
                timetableId: _effectiveTimetableId,
                slotId: question.slotId,
                userRole: widget.userRole ?? 'teacher',
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking answers: $e')),
        );
      }
    }
  }

  Future<double?> _selectScore(BuildContext context) async {
    double? score;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Enter Score'),
        content: TextField(
          keyboardType: TextInputType.number,
          onChanged: (value) => score = double.tryParse(value),
          decoration: const InputDecoration(hintText: '0-100'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, score ?? 0.0),
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
        title: const Text('Enter Remarks'),
        content: TextField(
          onChanged: (value) => remarks = value,
          decoration: const InputDecoration(hintText: 'Remarks'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, remarks ?? ''),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return remarks;
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Teacher Canvas'),
        actions: [
          if (_selectedTimetable != null)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _addQuestion,
            ),
        ],
      ),
      body: Column(
        children: [
          DropdownButton<Timetable>(
            hint: const Text('Select Timetable'),
            value: _selectedTimetable,
            items: _timetables.map((t) {
              final slots = _timetableSlots[t.id] ?? [];
              if (slots.isEmpty) {
                return const DropdownMenuItem<Timetable>(
                  value: null,
                  child: Text('No slots'),
                );
              }
              final timeSlot = slots.first.timeSlot?.split(' ').last ?? 'N/A';
              final classId = slots.first.classId;
              final classData = _class?.id == classId
                  ? _class
                  : null ??
                      ClassData(
                        id: '',
                        teacherId: '',
                        subjectId: '',
                        gradeId: '',
                        title: 'Unknown',
                        createdAt: 0,
                        learnerIds: [],
                      );
              final subjects =
                  Provider.of<List<Subject>>(context, listen: false);
              final grades = Provider.of<List<Grade>>(context, listen: false);
              final subject = subjects.firstWhere(
                  (s) => s.id == classData?.subjectId,
                  orElse: () => Subject(id: '', name: 'Unknown'));
              final grade = grades.firstWhere((g) => g.id == classData?.gradeId,
                  orElse: () => Grade(id: '', number: '0'));
              return DropdownMenuItem<Timetable>(
                value: t,
                child:
                    Text('$timeSlot - ${subject.name} (Grade ${grade.number})'),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedTimetable = value;
                  _resolveTimetableAndSlotId();
                  _loadClassData();
                  _loadQuestions();
                  _loadAssessments();
                });
              }
            },
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final question = _questions[index];
                return ListTile(
                  title: Text(
                      'Question ${index + 1}${question.pdfPage != null ? " (PDF Page ${question.pdfPage})" : ""}'),
                  subtitle: const Text('Handwritten'),
                  onTap: () => _viewQuestion(question),
                  trailing: IconButton(
                    icon: const Icon(Icons.check_circle),
                    onPressed: () => _markAnswers(question),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<List<User>> getUsersByClassId(
      BuildContext context, String classId) async {
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error fetching users: $e')),
        );
      }
      return [];
    }
  }
}
