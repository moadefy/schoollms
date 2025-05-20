import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../services/database_service.dart';
import '../models.dart';
import '../widgets/canvas_widget.dart';

class TeacherCanvasScreen extends StatefulWidget {
  final String teacherId;

  TeacherCanvasScreen({required this.teacherId});

  @override
  _TeacherCanvasScreenState createState() => _TeacherCanvasScreenState();
}

class _TeacherCanvasScreenState extends State<TeacherCanvasScreen> {
  List<Timetable> _timetables = [];
  Timetable? _selectedTimetable;
  List<Question> _questions = [];
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _loadTimetables();
  }

  Future<void> _loadTimetables() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final classes = await db._db.query('classes', where: 'teacherId = ?', whereArgs: [widget.teacherId]);
    final timetables = <Timetable>[];
    for (var cls in classes) {
      final classTimetables = await db.getTimetables(cls['id']);
      timetables.addAll(classTimetables);
    }
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
    setState(() {
      _questions = questions;
    });
  }

  Future<void> _addQuestion() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    String canvasData = jsonEncode([]);
    final questionId = Uuid().v4();

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Draw Question'),
            actions: [
              IconButton(
                icon: Icon(Icons.save),
                onPressed: () async {
                  final question = Question(
                    id: questionId,
                    timetableId: _selectedTimetable!.id,
                    classId: _selectedTimetable!.classId,
                    content: canvasData,
                  );
                  try {
                    await db.insertQuestion(question);
                    setState(() {
                      _questions.add(question);
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Question saved')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
                  }
                },
              ),
            ],
          ),
          body: CanvasWidget(
            initialData: canvasData,
            onChanged: (data) => canvasData = data,
          ),
        ),
      ),
    );
  }

  Future<void> _viewQuestion(Question question) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('Question${question.pdfPage != null ? " (PDF Page ${question.pdfPage})" : ""}')),
          body: CanvasWidget(
            initialData: question.content,
            pdfPage: question.pdfPage,
            // Placeholder: pdfData requires native PDF rendering
            readOnly: true,
            onChanged: (_) {},
          ),
        ),
      ),
    );
  }

  Future<void> _showResults(Question question) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final answers = await db.getAnswersByQuestion(question.id);

    // Analytics: Stroke count and drawing time
    int totalStrokes = 0;
    double avgComplexity = 0;
    for (var answer in answers) {
      final elements = jsonDecode(answer.content) as List;
      totalStrokes += elements.where((e) => e['type'] == 'stroke').length;
      final strokes = elements.where((e) => e['type'] == 'stroke').toList();
      if (strokes.isNotEmpty) {
        final points = strokes.expand((s) => s['points']).toList();
        final minX = points.map((p) => p['x']).reduce((a, b) => a < b ? a : b);
        final maxX = points.map((p) => p['x']).reduce((a, b) => a > b ? a : b);
        final minY = points.map((p) => p['y']).reduce((a, b) => a < b ? a : b);
        final maxY = points.map((p) => p['y']).reduce((a, b) => a > b ? a : b);
        avgComplexity += ((maxX - minX) * (maxY - minY)) / answers.length;
      }
    }

    // Heatmap for stroke density
    ```chartjs
    {
      "type": "scatter",
      "data": {
        "datasets": [
          ${answers.map((answer) {
            final elements = jsonDecode(answer.content) as List;
            final points = elements.where((e) => e['type'] == 'stroke').expand((e) => e['points']).toList();
            return '''
            {
              "label": "Answer ${answer.learnerId}",
              "data": ${jsonEncode(points.map((p) => {'x': p['x'], 'y': p['y']}).toList())},
              "backgroundColor": "rgba(75, 192, 192, 0.5)",
              "pointRadius": 3
            }
            ''';
          }).join(',')}
        ]
      },
      "options": {
        "scales": {
          "x": { "title": { "display": true, "text": "X Position" } },
          "y": { "title": { "display": true, "text": "Y Position" } }
        }
      }
    }
    ```

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Student Answers'),
        content: Container(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Total Strokes: $totalStrokes'),
              Text('Average Complexity: ${avgComplexity.toStringAsFixed(2)} px²'),
              TextField(
                decoration: InputDecoration(labelText: 'Filter by student'),
                onChanged: (value) => setState(() => _filter = value),
              ),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: answers.length,
                  itemBuilder: (context, index) {
                    final answer = answers[index];
                    return FutureBuilder<Map<String, dynamic>>(
                      future: db._db.query('learners', where: 'id = ?', whereArgs: [answer.learnerId]),
                      builder: (context, snapshot) {
                        final name = snapshot.hasData ? snapshot.data!['name'] : 'Loading...';
                        if (_filter.isNotEmpty && !name.toLowerCase().contains(_filter.toLowerCase())) {
                          return Container();
                        }
                        return ListTile(
                          title: Text(name),
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Scaffold(
                                appBar: AppBar(title: Text('Answer by $name')),
                                body: CanvasWidget(
                                  initialData: answer.content,
                                  pdfPage: question.pdfPage,
                                  // Placeholder: pdfData requires native rendering
                                  readOnly: true,
                                  onChanged: (_) {},
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Teacher Canvas'),
        actions: [
          if (_selectedTimetable != null)
            IconButton(
              icon: Icon(Icons.add),
              onPressed: _addQuestion,
            ),
        ],
      ),
      body: Column(
        children: [
          DropdownButton<Timetable>(
            hint: Text('Select Timetable'),
            value: _selectedTimetable,
            items: _timetables.map((t) => DropdownMenuItem(
                  value: t,
                  child: Text(t.timeSlot),
                )).toList(),
            onChanged: (value) {
              setState(() {
                _selectedTimetable = value;
                _loadQuestions();
              });
            },
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final question = _questions[index];
                return ListTile(
                  title: Text('Question ${index + 1}${question.pdfPage != null ? " (PDF Page ${question.pdfPage})" : ""}'),
                  subtitle: Text('Handwritten'),
                  onTap: () => _viewQuestion(question),
                  trailing: IconButton(
                    icon: Icon(Icons.analytics),
                    onPressed: () => _showResults(question),
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