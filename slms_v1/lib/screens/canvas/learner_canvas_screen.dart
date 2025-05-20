import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:pdf_render/pdf_render.dart';
import '../services/database_service.dart';
import '../models.dart';
import '../widgets/canvas_widget.dart';

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
  Map<String, String> _answers = {};
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
    final questions = await db.getQuestionsByTimetable(_selectedTimetable!.id);
    final answers = await db
        .getAnswersByQuestion(questions.isNotEmpty ? questions[0].id : '');
    int maxPages = questions.length;
    for (var question in questions) {
      final json = jsonDecode(question.content);
      final assets =
          (json['assets'] as List).map((j) => Asset.fromJson(j)).toList();
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
        for (var answer
            in answers.where((a) => a.learnerId == widget.learnerId))
          answer.questionId: answer.content
      };
      _totalPages = maxPages;
    });
  }

  Future<void> _submitAnswer(
      Question question, String canvasData, Analytics? analytics) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final answer = Answer(
      id: Uuid().v4(),
      questionId: question.id,
      learnerId: widget.learnerId,
      content: canvasData,
      submitted_at: DateTime.now().millisecondsSinceEpoch,
    );
    try {
      await db.insertAnswer(answer);
      if (analytics != null) {
        analytics.questionId = question.id;
        analytics.learnerId = widget.learnerId;
        await db.insertAnalytics(analytics);
      }
      setState(() {
        _answers[question.id] = canvasData;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Answer submitted')),
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
                      child: Text(t.timeSlot),
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
                      final initialData = _answers[question.id];
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
                                initialData: question.content,
                                readOnly: true,
                                pageIndex: pageIndex,
                                onChanged: (_, __) {},
                              ),
                            ),
                            Divider(),
                            Expanded(
                              child: CanvasWidget(
                                initialData: initialData,
                                pageIndex: pageIndex,
                                onChanged: (data, analytics) =>
                                    _submitAnswer(question, data, analytics),
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
