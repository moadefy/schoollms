import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/database_service.dart';
import '../../models/learnertimetable.dart';
import '../../models/question.dart';
import '../../widgets/canvas_widget.dart';

class LearnerCanvasScreen extends StatefulWidget {
  final String learnerId;

  const LearnerCanvasScreen({Key? key, required this.learnerId})
      : super(key: key);

  @override
  State<LearnerCanvasScreen> createState() => _LearnerCanvasScreenState();
}

class _LearnerCanvasScreenState extends State<LearnerCanvasScreen> {
  List<LearnerTimetable> _timetables = [];
  Map<String, dynamic> _answerData = {};
  Question? _currentQuestion;

  @override
  void initState() {
    super.initState();
    _loadTimetables();
    _loadQuestion();
  }

  Future<void> _loadTimetables() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final timetables = await dbService.getLearnerTimetables(widget.learnerId);
    setState(() {
      _timetables = timetables;
    });
  }

  Future<void> _loadQuestion() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final questions = await dbService
        .getQuestions(_timetables.isNotEmpty ? _timetables[0].classId : '');
    setState(() {
      _currentQuestion = questions.isNotEmpty
          ? questions[0]
          : Question(
              id: 'q001',
              classId: _timetables.isNotEmpty ? _timetables[0].classId : '',
              timetableId: _timetables.isNotEmpty ? _timetables[0].id : '',
              content: 'Draw the water cycle',
            );
    });
  }

  void _saveAnswer() {
    // Placeholder: Save answer to database (requires Answer model and table)
    // final dbService = Provider.of<DatabaseService>(context, listen: false);
    // final answerJson = jsonEncode(_answerData);
    // await dbService.insertAnswer(Answer(
    //   id: 'a${DateTime.now().millisecondsSinceEpoch}',
    //   questionId: _currentQuestion!.id,
    //   learnerId: widget.learnerId,
    //   answer: answerJson,
    // ));
    // ignore: avoid_print
    print('Answer saved: $_answerData');
  }

  void _updateAnswer(Map<String, dynamic> data) {
    setState(() {
      _answerData = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learner Canvas')),
      body: Column(
        children: [
          // Display timetable
          Expanded(
            flex: 1,
            child: ListView.builder(
              itemCount: _timetables.length,
              itemBuilder: (context, index) {
                final timetable = _timetables[index];
                return ListTile(
                  title: Text('Class: ${timetable.classId}'),
                  subtitle: Text('Time: ${timetable.timeSlot}'),
                );
              },
            ),
          ),
          // Display question and canvas
          Expanded(
            flex: 2,
            child: _currentQuestion == null
                ? const Center(child: Text('No question available'))
                : Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Text(
                          _currentQuestion!.content,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Expanded(
                        child: CanvasWidget(
                          learnerId: widget.learnerId,
                          onSave: _saveAnswer,
                          onUpdate: _updateAnswer,
                        ),
                      ),
                      ElevatedButton(
                        onPressed: _saveAnswer,
                        child: const Text('Submit Answer'),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
