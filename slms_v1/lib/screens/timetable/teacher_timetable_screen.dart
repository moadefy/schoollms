import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/database_service.dart';
import '../../models/timetable.dart';
import '../../models/class.dart';
import '../../models/learner.dart';

class TeacherTimetableScreen extends StatefulWidget {
  final String teacherId;

  const TeacherTimetableScreen({Key? key, required this.teacherId})
      : super(key: key);

  @override
  TeacherTimetableScreenState createState() => TeacherTimetableScreenState();
}

class TeacherTimetableScreenState extends State<TeacherTimetableScreen> {
  List<Class> _classes = [];
  List<Timetable> _timetables = [];
  List<Learner> _learners = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final classes = await dbService.getClasses(widget.teacherId);
    final timetables = await dbService.getTimetables(widget.teacherId);
    final learnerIds =
        classes.map((c) => c.learnerIds).expand((i) => i).toSet();
    final learners = <Learner>[];
    for (final id in learnerIds) {
      final learnerList = await dbService.getLearners(id);
      learners.addAll(learnerList);
    }
    if (mounted) {
      setState(() {
        _classes = classes;
        _timetables = timetables;
        _learners = learners;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Teacher Timetable')),
      body: Column(
        children: [
          // Classes Section
          const Padding(
            padding: EdgeInsets.all(8.0),
            child:
                Text('Classes', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 1,
            child: _classes.isEmpty
                ? const Center(child: Text('No classes available'))
                : ListView.builder(
                    itemCount: _classes.length,
                    itemBuilder: (context, index) {
                      final classObj = _classes[index];
                      return ListTile(
                        title: Text(
                            '${classObj.subject} - Grade ${classObj.grade}'),
                        onTap: () => _showLearnersDialog(context, classObj),
                      );
                    },
                  ),
          ),
          // Timetables Section
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Timetable',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            flex: 2,
            child: _timetables.isEmpty
                ? const Center(child: Text('No timetable available'))
                : ListView.builder(
                    itemCount: _timetables.length,
                    itemBuilder: (context, index) {
                      final timetable = _timetables[index];
                      return ListTile(
                        title: Text(timetable.subject),
                        subtitle: Text(
                            '${timetable.day} ${timetable.startTime}-${timetable.endTime}'),
                        onTap: () => _editTimetable(context, timetable),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTimetable(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showLearnersDialog(BuildContext context, Class classObj) {
    final classLearners =
        _learners.where((l) => classObj.learnerIds.contains(l.id)).toList();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Learners'),
        content: SizedBox(
          width: double.maxFinite,
          child: classLearners.isEmpty
              ? const Text('No learners in this class')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: classLearners.length,
                  itemBuilder: (context, index) {
                    final learner = classLearners[index];
                    return ListTile(
                      title: Text(learner.name),
                      subtitle: Text('Grade ${learner.grade}'),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _addTimetable(BuildContext context) async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final newTimetable = Timetable(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      teacherId: widget.teacherId,
      classId: _classes.isNotEmpty ? _classes[0].id : '',
      subject: 'New Subject',
      startTime: '09:00',
      endTime: '10:00',
      day: 'Monday',
      timeSlot: 'Morning',
    );
    await dbService.insertTimetable(newTimetable);
    if (mounted) {
      await _loadData();
    }
  }

  void _editTimetable(BuildContext context, Timetable timetable) async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final updatedTimetable = Timetable(
      id: timetable.id,
      teacherId: timetable.teacherId,
      classId: timetable.classId,
      subject: '${timetable.subject} (Edited)',
      startTime: timetable.startTime,
      endTime: timetable.endTime,
      day: timetable.day,
      timeSlot: timetable.timeSlot,
    );
    await dbService.insertTimetable(updatedTimetable);
    if (mounted) {
      await _loadData();
    }
  }
}
