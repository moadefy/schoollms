import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/database_service.dart';
import '../../models/timetable.dart';
import '../../models/question.dart';
import '../../models/answer.dart';

class TeacherCanvasScreen extends StatefulWidget {
  final String teacherId;

  const TeacherCanvasScreen({Key? key, required this.teacherId})
      : super(key: key);

  @override
  State<TeacherCanvasScreen> createState() => _TeacherCanvasScreenState();
}

class _TeacherCanvasScreenState extends State<TeacherCanvasScreen> {
  List<Timetable> _timetables = [];
  List<Question> _questions = [];
  List<Answer> _answers = [];
  String _newQuestionContent = '';
  Timetable? _selectedTimetable;

  @override
  void initState() {
    super.initState();
    _loadTimetables();
  }

  Future<void> _loadTimetables() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final timetables = await dbService.getTimetables(widget.teacherId);
    setState(() {
      _timetables = timetables;
      _selectedTimetable = timetables.isNotEmpty ? timetables[0] : null;
    });
    if (_selectedTimetable != null) {
      _loadQuestions();
      _loadAnswers();
    }
  }

  Future<void> _loadQuestions() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final questions = await dbService.getQuestions(_selectedTimetable!.classId);
    setState(() {
      _questions = questions;
    });
  }

  Future<void> _loadAnswers() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final answers = await dbService.getAnswers(_selectedTimetable!.classId);
    setState(() {
      _answers = answers;
    });
  }

  Future<void> _createQuestion() async {
    if (_newQuestionContent.isEmpty || _selectedTimetable == null) return;
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final question = Question(
      id: 'q${DateTime.now().millisecondsSinceEpoch.toString()}',
      classId: _selectedTimetable!.classId,
      timetableId: _selectedTimetable!.id,
      content: _newQuestionContent,
    );
    await dbService.insertQuestion(question);
    setState(() {
      _questions.add(question);
      _newQuestionContent = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Canvas')),
      body: Column(
        children: [
          // Timetable selection
          DropdownButton<Timetable>(
            value: _selectedTimetable,
            hint: const Text('Select Timetable'),
            onChanged: (Timetable? newValue) {
              setState(() {
                _selectedTimetable = newValue;
              });
              if (newValue != null) {
                _loadQuestions();
                _loadAnswers();
              }
            },
            items: _timetables.map((Timetable timetable) {
              return DropdownMenuItem<Timetable>(
                value: timetable,
                child: Text('${timetable.subject} - ${timetable.timeSlot}'),
              );
            }).toList(),
          ),
          // Create question
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'New Question',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) {
                      _newQuestionContent = value;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _createQuestion,
                  child: const Text('Add Question'),
                ),
              ],
            ),
          ),
          // Questions list
          Expanded(
            flex: 1,
            child: ListView.builder(
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final question = _questions[index];
                return ListTile(
                  title: Text(question.content),
                  subtitle: Text('Class: ${question.classId}'),
                );
              },
            ),
          ),
          // Answers review
          Expanded(
            flex: 2,
            child: _answers.isEmpty
                ? const Center(child: Text('No answers available'))
                : ListView.builder(
                    itemCount: _answers.length,
                    itemBuilder: (context, index) {
                      final answer = _answers[index];
                      final answerData = jsonDecode(answer.answer) as List;
                      final points = answerData
                          .map((p) => Offset(
                                (p['x'] as num).toDouble(),
                                (p['y'] as num).toDouble(),
                              ))
                          .toList();
                      return Card(
                        child: Column(
                          children: [
                            ListTile(
                              title: Text('Learner: ${answer.learnerId}'),
                              subtitle: Text('Question: ${answer.questionId}'),
                            ),
                            SizedBox(
                              height: 100,
                              child: CustomPaint(
                                painter: CanvasPainter(points),
                                size: Size.infinite,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          // Answer stats visualization
          SizedBox(
            height: 100,
            child: CustomPaint(
              painter: AnswerStatsPainter(_answers.length),
              size: Size.infinite,
            ),
          ),
        ],
      ),
    );
  }
}

class CanvasPainter extends CustomPainter {
  final List<Offset> points;

  CanvasPainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;
}

class AnswerStatsPainter extends CustomPainter {
  final int answerCount;

  AnswerStatsPainter(this.answerCount);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
    final barWidth = size.width / 5;
    final barHeight = answerCount * 10.0; // Scale height by answer count
    canvas.drawRect(
      Rect.fromLTWH(0, size.height - barHeight, barWidth, barHeight),
      paint,
    );
    final textPainter = TextPainter(
      text: TextSpan(
        text: '$answerCount Answers',
        style: const TextStyle(color: Colors.black, fontSize: 12),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(
        canvas, Offset(barWidth / 2, size.height - barHeight - 20));
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
