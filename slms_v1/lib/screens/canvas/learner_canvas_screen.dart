import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:pdf_render/pdf_render.dart';
import 'dart:convert'; // Added for jsonDecode
import 'package:schoollms/services/database_service.dart';
import 'package:schoollms/models/learnertimetable.dart'; // Corrected for LearnerTimetable
import 'package:schoollms/models/question.dart'; // For Question
import 'package:schoollms/models/answer.dart'; // For Answer
import 'package:schoollms/models/asset.dart'; // For Asset
import 'package:schoollms/models/analytics.dart'; // For Analytics
import 'package:schoollms/widgets/canvas_widget.dart';

class LearnerCanvasScreen extends StatefulWidget {
  final String learnerId;

  LearnerCanvasScreen({required this.learnerId});

  @override
  _LearnerCanvasScreenState createState() => _LearnerCanvasScreenState();
}

class _LearnerCanvasScreenState extends State<LearnerCanvasScreen> {
  List<LearnerTimetable> _timetables = [];
  LearnerTimetable? _selectedTimetable;
  List<Question> _questions = [];
  Map<String, dynamic> _answers = {}; // Updated to store strokes and assets
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _loadTimetables();
  }

  Future<void> _loadTimetables() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final timetables = await db.getLearnerTimetable(widget.learnerId);
    setState(() {
      _timetables = timetables;
      _selectedTimetable = timetables.isNotEmpty ? timetables[0] : null;
      if (_selectedTimetable != null) {
        _loadQuestions();
      }
    });
  }

  Future<void> _loadQuestions() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final questions = await db.getQuestionsByClass(
        _selectedTimetable!.classId); // Updated to use classId
    final answers = await db.getAnswersByLearner(
        widget.learnerId); // Updated to fetch all learner answers
    int maxPages = questions.length;
    for (var question in questions) {
      final assets = await db
          .getAssetsByLearner(widget.learnerId); // Fetch assets for learner
      final pdfAssets = assets.where((a) => a.type == 'pdf').toList();
      for (var pdf in pdfAssets) {
        final doc = await PdfDocument.openData(base64Decode(pdf.data));
        maxPages = maxPages > doc.pageCount ? maxPages : doc.pageCount;
        doc.dispose();
      }
    }
    setState(() {
      _questions = questions;
      _answers = {
        for (var answer in answers)
          answer.questionId: {
            'strokes': jsonDecode(answer.strokes.isNotEmpty
                ? answer.strokes[0].toString()
                : '[]'),
            'assets':
                answer.assets.map((a) => Asset.fromJson(a).toJson()).toList(),
          }
      };
      _totalPages = maxPages;
    });
  }

  Future<void> _submitAnswer(Question question, Map<String, dynamic> canvasData,
      List<CanvasAsset> updatedAssets) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final answer = Answer(
      id: Uuid().v4(),
      questionId: question.id,
      learnerId: widget.learnerId,
      strokes: (canvasData['strokes'] as List)
          .map((s) => Stroke.fromJson(s).toJson())
          .toList(),
      assets: updatedAssets
          .map((a) => Asset(
                id: a.id,
                learnerId: widget.learnerId,
                questionId: question.id,
                type: a.type,
                data: a.path, // Corrected to use path instead of data
                positionX: a.position.dx,
                positionY: a.position.dy,
                scale: a.scale,
                created_at: DateTime.now().millisecondsSinceEpoch,
              ).toJson())
          .toList(),
      submitted_at: DateTime.now().millisecondsSinceEpoch,
    );
    DateTime startTime = DateTime.now();
    try {
      await db.insertAnswer(answer);
      // Log analytics
      DateTime endTime = DateTime.now();
      final timeSpent = endTime.difference(startTime).inSeconds;
      final analytics = Analytics(
        questionId: question.id,
        learnerId: widget.learnerId,
        timeSpentSeconds: timeSpent,
        submissionStatus: 'submitted',
        deviceId:
            'device_${widget.learnerId}', // Replace with actual device ID logic if available
        timestamp: endTime.millisecondsSinceEpoch,
      );
      await db.insertAnalytics(analytics);
      setState(() {
        _answers[question.id] = canvasData;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Answer submitted')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Learner Canvas')),
      body: Column(
        children: [
          DropdownButton<LearnerTimetable>(
            hint: Text('Select Timetable'),
            value: _selectedTimetable,
            items: _timetables
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Text(t.timeSlot ?? 'No Time'),
                    ))
                .toList(),
            onChanged: (value) {
              setState(() {
                _selectedTimetable = value;
                _loadQuestions();
              });
            },
          ),
          Expanded(
            child: _questions.isEmpty
                ? Center(child: Text('No questions available'))
                : PageView.builder(
                    itemCount: _totalPages,
                    itemBuilder: (context, pageIndex) {
                      final questionIndex = pageIndex % _questions.length;
                      final question = _questions[questionIndex];
                      final answerData = _answers[question.id] ??
                          {'strokes': [], 'assets': []};
                      final initialStrokes = jsonEncode(answerData['strokes']);
                      final initialAssets = (answerData['assets'] as List)
                          .map((a) => CanvasAsset(
                                id: a['id'],
                                type: a['type'],
                                path: a['path'],
                                pageIndex: a['pageIndex'],
                                position:
                                    Offset(a['positionX'], a['positionY']),
                                scale: a['scale'],
                              ))
                          .toList();
                      return AnimatedOpacity(
                        opacity: 1.0,
                        duration: Duration(milliseconds: 300),
                        child: Column(
                          children: [
                            Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Text('Question ${pageIndex + 1}'),
                            ),
                            Expanded(
                              child: CanvasWidget(
                                learnerId: widget.learnerId,
                                strokes: question.content,
                                readOnly: true,
                                onSave: () {},
                                onUpdate: (data) {},
                                initialAssets: initialAssets,
                              ),
                            ),
                            Divider(),
                            Expanded(
                              child: CanvasWidget(
                                learnerId: widget.learnerId,
                                strokes: initialStrokes,
                                readOnly: false,
                                onSave: () {},
                                onUpdate: (data) {
                                  _submitAnswer(
                                      question,
                                      data,
                                      (data['assets'] as List<CanvasAsset>? ??
                                              [])
                                          .toList());
                                },
                                initialAssets: initialAssets,
                                onAssetsUpdate: (updatedAssets) {
                                  setState(() {
                                    _answers[question.id] = {
                                      'strokes': answerData['strokes'],
                                      'assets': updatedAssets
                                          .map((a) => a.toJson())
                                          .toList(),
                                    };
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
