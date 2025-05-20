import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_draggable_gridview/flutter_draggable_gridview.dart';
import 'package:uuid/uuid.dart';
import 'database_service.dart';
import 'models.dart';

class TeacherTimetableScreen extends StatefulWidget {
  final String teacherId;

  TeacherTimetableScreen({this.teacherId});

  @override
  _TeacherTimetableScreenState createState() => _TeacherTimetableScreenState();
}

class _TeacherTimetableScreenState extends State<TeacherTimetableScreen> {
  List<Class> _classes = [];
  List<Learner> _learners = [];
  List<DraggableGridItem> _gridItems = [];
  final _timeSlots = [
    '09:00-10:00',
    '10:00-11:00',
    '11:00-12:00',
    '12:00-13:00',
    '13:00-14:00',
  ];
  DateTime _selectedDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadClasses();
    _loadGridItems();
  }

  Future<void> _loadClasses() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      final classes = await db._db.query('classes',
          where: 'teacherId = ?', whereArgs: [widget.teacherId]);
      setState(() {
        _classes = classes
            .map((map) => Class(
                  id: map['id'],
                  teacherId: map['teacherId'],
                  subject: map['subject'],
                  grade: map['grade'],
                ))
            .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading classes: $e')),
      );
    }
  }

  Future<void> _loadGridItems() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      final timetables =
          await db.getTimetables(_classes.isNotEmpty ? _classes[0].id : '');
      setState(() {
        _gridItems = List.generate(
            _timeSlots.length,
            (index) => DraggableGridItem(
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: 300),
                    color: Colors.green[100],
                    child: Center(
                        child: Text(_timeSlots[index],
                            style: TextStyle(color: Colors.grey))),
                  ),
                  isDraggable: false,
                ));
        for (var timetable in timetables) {
          final slotIndex =
              _timeSlots.indexOf(timetable.timeSlot.split(' ')[1]);
          if (slotIndex != -1) {
            _gridItems[slotIndex] = DraggableGridItem(
              child: TimetableCard(timetable: timetable),
              isDraggable: true,
            );
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading timetables: $e')),
      );
    }
  }

  Future<void> _showAddTimetableDialog(
      BuildContext context, int slotIndex) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    Class selectedClass;
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
                    _loadLearners(value.grade).then((learners) {
                      setState(() {
                        _learners = learners;
                      });
                    });
                  });
                },
              ),
              ElevatedButton(
                onPressed: () async {
                  final result = await showDialog<List<String>>(
                    context: context,
                    builder: (context) =>
                        LearnerSelectionDialog(learners: _learners),
                  );
                  if (result != null) {
                    setState(() {
                      selectedLearnerIds = result;
                    });
                  }
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
                if (selectedClass != null) {
                  final timeSlot =
                      '${_selectedDay.toIso8601String().split('T')[0]} ${_timeSlots[slotIndex]}';
                  final timetable = Timetable(
                    id: Uuid().v4(),
                    classId: selectedClass.id,
                    timeSlot: timeSlot,
                    learnerIds: selectedLearnerIds,
                  );
                  try {
                    await db.insertTimetable(timetable);
                    setState(() {
                      _gridItems[slotIndex] = DraggableGridItem(
                        child: TimetableCard(timetable: timetable),
                        isDraggable: true,
                      );
                    });
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Timetable added successfully')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error: $e')),
                    );
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

  Future<List<Learner>> _loadLearners(String grade) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      return await db.getLearnersByGrade(grade);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading learners: $e')),
      );
      return [];
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
                  _loadGridItems();
                });
              }
            },
          ),
        ],
      ),
      body: DraggableGridViewBuilder(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 1,
          childAspectRatio: 4,
        ),
        children: _gridItems,
        isOnlyLongPress: false,
        dragCompletion:
            (List<DraggableGridItem> items, int from, int to) async {
          final db = Provider.of<DatabaseService>(context, listen: false);
          setState(() {
            final dragged = _gridItems[from];
            _gridItems[from] = DraggableGridItem(
              child: AnimatedContainer(
                duration: Duration(milliseconds: 300),
                color: Colors.green[100],
                child: Center(
                    child: Text(_timeSlots[from],
                        style: TextStyle(color: Colors.grey))),
              ),
              isDraggable: false,
            );
            _gridItems[to] = dragged;
            if (dragged.child is TimetableCard) {
              final timetable = (dragged.child as TimetableCard).timetable;
              final newTimeSlot =
                  '${_selectedDay.toIso8601String().split('T')[0]} ${_timeSlots[to]}';
              final updatedTimetable = Timetable(
                id: timetable.id,
                classId: timetable.classId,
                timeSlot: newTimeSlot,
                learnerIds: timetable.learnerIds,
              );
              try {
                db.insertTimetable(updatedTimetable);
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error updating timetable: $e')),
                );
                // Revert drag
                setState(() {
                  _gridItems[to] = _gridItems[from];
                  _gridItems[from] = dragged;
                });
              }
            }
          });
        },
        dragFeedback: (index) => Transform.scale(
          scale: 1.1,
          child: Material(
            elevation: 8,
            child: Container(
              width: 200,
              height: 50,
              child: _gridItems[index].child,
            ),
          ),
        ),
        dragPlaceHolder: (index) => PlaceHolderWidget(
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            color: Colors.blue[100],
          ),
        ),
        onTap: (index) {
          if (_gridItems[index].child is AnimatedContainer) {
            _showAddTimetableDialog(context, index);
          }
        },
      ),
    );
  }
}

class TimetableCard extends StatelessWidget {
  final Timetable timetable;

  TimetableCard({this.timetable});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      color: Colors.blue[200],
      child: ListTile(
        title: Text(timetable.timeSlot.split(' ')[1],
            style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: FutureBuilder<Map<String, dynamic>>(
          future: Provider.of<DatabaseService>(context)._db.query('classes',
              where: 'id = ?',
              whereArgs: [
                timetable.classId
              ]).then((maps) => maps.isNotEmpty ? maps[0] : {}),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return Text('Loading...');
            return Text(
                '${snapshot.data['subject']} (Grade ${snapshot.data['grade']})');
          },
        ),
        trailing: Text('${timetable.learnerIds.length} Learners'),
      ),
    );
  }
}

class LearnerSelectionDialog extends StatefulWidget {
  final List<Learner> learners;

  LearnerSelectionDialog({this.learners});

  @override
  _LearnerSelectionDialogState createState() => _LearnerSelectionDialogState();
}

class _LearnerSelectionDialogState extends State<LearnerSelectionDialog> {
  List<String> selectedLearnerIds = [];

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
                  if (value) {
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
