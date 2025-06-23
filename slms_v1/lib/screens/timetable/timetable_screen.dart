import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:schoollms/services/database_service.dart';
import 'package:schoollms/models/learner.model.dart';
import 'package:schoollms/models/teacher.model.dart';
import 'package:schoollms/models/class.model.dart';
import 'package:schoollms/models/learner.dart';
import 'package:schoollms/models/timetable.dart';
import 'package:schoollms/models/timetable_slot.dart';
import 'package:device_info_plus/device_info_plus.dart';

class TimetableScreen extends StatefulWidget {
  @override
  _TimetableScreenState createState() => _TimetableScreenState();
}

class _TimetableScreenState extends State<TimetableScreen> {
  late String userId;
  late String role;
  late List<Map<String, dynamic>> timetableSlots = [];
  late List<LearnerData> learners = [];
  final List<String> timeSlots = [
    '09:00-10:00',
    '10:00-11:00',
    '11:00-12:00',
    '12:00-13:00',
    '13:00-14:00',
  ];
  late DateTime selectedDay;
  String? deviceId;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    selectedDay = DateTime.now();
    deviceId = null;
    isLoading = true;
    errorMessage = null;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    userId = args['userId'];
    role = args['role'];
    if (deviceId == null) _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    try {
      await _initializeDeviceId();
      await _loadTimetableSlots();
    } catch (e) {
      if (mounted) setState(() => errorMessage = 'Error loading data: $e');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _initializeDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Theme.of(context).platform == TargetPlatform.android) {
      final androidInfo = await deviceInfo.androidInfo;
      if (mounted) setState(() => deviceId = androidInfo.id);
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      final iosInfo = await deviceInfo.iosInfo;
      if (mounted) setState(() => deviceId = iosInfo.identifierForVendor);
    } else {
      if (mounted) setState(() => deviceId = 'teacher_device_$userId');
    }
  }

  Future<void> _loadTimetableSlots() async {
    setState(() => isLoading = true);
    try {
      final db = Provider.of<DatabaseService>(context, listen: false);
      if (role == 'teacher') {
        final slots = await db.getTeacherTimetableSlots(userId);
        setState(() {
          timetableSlots = slots.isEmpty
              ? [
                  {'timeSlot': '09:00-10:00', 'subject': 'Math'},
                  {'timeSlot': '10:00-11:00', 'subject': 'Science'},
                ]
              : slots;
          isLoading = false;
          if (timetableSlots.isEmpty)
            errorMessage =
                'No timetables found. Add a new timetable to get started.';
        });
      } else if (role == 'learner') {
        final learner = await db.getLearnerDataById(userId);
        List<Map<String, dynamic>> slots = [];
        if (learner != null) {
          slots = await db.getLearnerTimetableSlots(learner.id);
        }
        setState(() {
          timetableSlots = slots;
          isLoading = false;
        });
      } else if (role == 'parent') {
        setState(() {
          timetableSlots = [];
          isLoading = false;
        });
      } else if (role == 'admin') {
        List<Map<String, dynamic>> slots = await db.getAllTimetableSlots();
        setState(() {
          timetableSlots = slots;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          errorMessage = 'Error loading timetable: $e';
          isLoading = false;
        });
    }
  }

  Future<void> _showAddTimetableDialog(
      BuildContext context, int slotIndex) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    String? selectedClassId;
    List<String> selectedLearnerIds = [];

    var classes = await db.getTeacherClassDataByTeacherId(userId);
    if (classes.isEmpty) {
      await _showAddClassDialog(context);
      classes =
          await db.getTeacherClassDataByTeacherId(userId); // Refresh classes
    }

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add Timetable Slot'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButton<String>(
                hint: const Text('Select Class'),
                value: selectedClassId,
                items: classes
                    .map((cls) => DropdownMenuItem(
                          value: cls.id,
                          child: Text(cls.title),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() => selectedClassId = value);
                  if (value != null) {
                    _loadLearners(value).then((learners) {
                      setState(() => this.learners = learners);
                    });
                  }
                },
              ),
              if (learners.isEmpty)
                ElevatedButton(
                  onPressed: () async {
                    await _showAddLearnerDialog(context);
                    final updatedLearners =
                        await _loadLearners(selectedClassId ?? '');
                    setState(() => this.learners = updatedLearners);
                  },
                  child: const Text('Register New Learner'),
                ),
              if (learners.isNotEmpty)
                ElevatedButton(
                  onPressed: () async {
                    final result = await showDialog<List<String>>(
                      context: context,
                      builder: (context) =>
                          LearnerSelectionDialog(learners: learners),
                    );
                    if (result != null) {
                      setState(() => selectedLearnerIds = result);
                      if (selectedClassId != null) {
                        final classData =
                            await db.getClassDataById(selectedClassId!);
                        final updatedLearnerIds = [
                          ...classData.learnerIds,
                          ...result
                        ];
                        await db.updateClassLearnerIds(
                            selectedClassId!,
                            updatedLearnerIds
                                .toSet()
                                .toList()); // Avoid duplicates
                      }
                    }
                  },
                  child: Text('Select Learners (${selectedLearnerIds.length})'),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (selectedClassId != null && selectedLearnerIds.isNotEmpty) {
                  final timeSlot =
                      '${selectedDay.toIso8601String().split('T')[0]} ${timeSlots[slotIndex]}';
                  final timetableId = const Uuid().v4();
                  final slots = [
                    {
                      'id': const Uuid().v4(),
                      'classId': selectedClassId,
                      'timeSlot': timeSlot,
                      'learnerIds': selectedLearnerIds,
                    },
                  ];
                  final timetable = Timetable(
                    id: timetableId,
                    teacherId: userId,
                    userRole: 'teacher',
                    userId: userId,
                  );
                  try {
                    await db.insertTimetable(timetable, slots);
                    await _loadTimetableSlots();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('Timetable slot added successfully')));
                  } catch (e) {
                    if (mounted)
                      setState(() =>
                          errorMessage = 'Error adding timetable slot: $e');
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddClassDialog(BuildContext context) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    String? subject;
    String? grade;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Class'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButton<String>(
              hint: const Text('Select Subject'),
              value: subject,
              items: ['Math', 'Science', 'English']
                  .map((s) => DropdownMenuItem(
                        value: s,
                        child: Text(s),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => subject = value),
            ),
            DropdownButton<String>(
              hint: const Text('Select Grade'),
              value: grade,
              items: ['10', '11', '12']
                  .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text('Grade $g'),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => grade = value),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (subject != null && grade != null) {
                final existingClasses =
                    await db.getTeacherClassDataByTeacherId(userId);
                final sameSubjectGradeClasses = existingClasses
                    .where(
                        (cls) => cls.subject == subject && cls.grade == grade)
                    .toList();
                int classNumber = sameSubjectGradeClasses.isEmpty
                    ? 1
                    : sameSubjectGradeClasses.map((cls) {
                          final match =
                              RegExp(r'Class (\d+)$').firstMatch(cls.title);
                          return match != null ? int.parse(match.group(1)!) : 0;
                        }).reduce((a, b) => a > b ? a : b) +
                        1;
                final classTitle = '$subject $grade Class $classNumber';
                final newClass = ClassData(
                  id: const Uuid().v4(),
                  teacherId: userId,
                  subject: subject!,
                  grade: grade!,
                  title: classTitle,
                  createdAt: DateTime.now().millisecondsSinceEpoch,
                );
                try {
                  await db.insertClassData(newClass);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Class added successfully')));
                } catch (e) {
                  if (mounted)
                    setState(() => errorMessage = 'Error adding class: $e');
                }
              }
            },
            child: const Text('Add Class'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddLearnerDialog(BuildContext context) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final learnerNameController = TextEditingController();
    String? grade;
    String? classId;
    final classes = await db.getTeacherClassDataByTeacherId(userId);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Register New Learner'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: learnerNameController,
              decoration: const InputDecoration(labelText: 'Learner Name'),
            ),
            DropdownButton<String>(
              hint: const Text('Select Grade'),
              value: grade,
              items: ['10', '11', '12']
                  .map((g) => DropdownMenuItem(
                        value: g,
                        child: Text('Grade $g'),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => grade = value),
            ),
            if (classes.isNotEmpty)
              DropdownButton<String>(
                hint: const Text('Select Class (Optional)'),
                value: classId,
                items: classes
                    .map((cls) => DropdownMenuItem(
                          value: cls.id,
                          child: Text(cls.title),
                        ))
                    .toList(),
                onChanged: (value) => setState(() => classId = value),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (learnerNameController.text.isNotEmpty && grade != null) {
                final newLearner = LearnerData(
                  id: const Uuid().v4(),
                  country: '', // Placeholder
                  citizenshipId: '', // Placeholder
                  name: learnerNameController.text,
                  surname: '', // Placeholder
                  homeLanguage: '', // Placeholder
                  preferredLanguage: '', // Placeholder
                  grade: grade!,
                  subjects: [], // Placeholder
                  parentDetails: ParentDetails(
                    id: const Uuid().v4(),
                    name: '', // Placeholder
                    surname: '', // Placeholder
                    email: '', // Placeholder
                    contactNumber: '', // Placeholder
                    occupation: '', // Placeholder
                  ),
                  classId: classId,
                );
                try {
                  await db.insertLearnerData(newLearner);
                  if (classId != null) {
                    final classData = await db.getClassDataById(classId!);
                    final updatedLearnerIds = [
                      ...classData.learnerIds,
                      newLearner.id
                    ];
                    await db.updateClassLearnerIds(classId!,
                        updatedLearnerIds.toSet().toList()); // Avoid duplicates
                  }
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Learner registered successfully')));
                } catch (e) {
                  if (mounted)
                    setState(
                        () => errorMessage = 'Error registering learner: $e');
                }
              }
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }

  Future<List<LearnerData>> _loadLearners(String classId) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      final classData = await db.getClassDataById(classId);
      if (classData != null) {
        final learnerIds = classData.learnerIds;
        final learners = await Future.wait(
            learnerIds.map((id) => db.getLearnerDataById(id)));
        return learners.whereType<LearnerData>().toList();
      }
      return [];
    } catch (e) {
      if (mounted) setState(() => errorMessage = 'Error loading learners: $e');
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('$role Timetable'),
        actions: [
          DropdownButton<String>(
            value: _getRangeLabel(),
            items: [
              DropdownMenuItem(value: 'Day', child: Text('Day')),
              DropdownMenuItem(value: 'Week', child: Text('Week')),
              DropdownMenuItem(value: 'Month', child: Text('Month')),
            ],
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedDay = DateTime.now(); // Reset to today
                  if (value == 'Week')
                    selectedDay = selectedDay.add(Duration(days: 7));
                  if (value == 'Month')
                    selectedDay = selectedDay.add(Duration(days: 30));
                  _loadTimetableSlots();
                });
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final selected = await showDatePicker(
                context: context,
                initialDate: selectedDay,
                firstDate: DateTime(2023),
                lastDate: DateTime(2030),
              );
              if (selected != null)
                setState(() {
                  selectedDay = selected;
                  _loadTimetableSlots();
                });
            },
          ),
          if (role == 'teacher')
            IconButton(
              icon: const Icon(Icons.class_),
              onPressed: () => _showAddClassDialog(context),
              tooltip: 'Add Class',
            ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
              ? Center(child: Text(errorMessage!))
              : GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 5,
                    childAspectRatio: 1.5,
                  ),
                  itemCount: timeSlots.length,
                  itemBuilder: (context, index) {
                    final timeSlot = timeSlots[index];
                    final fullTimeSlot =
                        '${selectedDay.toIso8601String().split('T')[0]} $timeSlot';
                    final slot = timetableSlots.firstWhere(
                      (s) => s['timeSlot'] == fullTimeSlot,
                      orElse: () => {},
                    );
                    final db =
                        Provider.of<DatabaseService>(context, listen: false);
                    int learnerCount = 0;
                    if (slot.isNotEmpty && slot['classId'] != null) {
                      try {
                        final classData = db.getClassDataById(slot['classId']);
                        learnerCount = (classData as Future<ClassData>)
                            .then((data) => data.learnerIds.length)
                            .catchError((_) => 0) as int;
                      } catch (e) {
                        learnerCount = 0;
                      }
                    }
                    return GestureDetector(
                      onTap: slot.isEmpty && role == 'teacher'
                          ? () => _showAddTimetableDialog(context, index)
                          : null,
                      child: Card(
                        color: slot.isNotEmpty
                            ? _getSubjectColor(slot['subject'] ?? 'Unknown')
                            : Colors.green[100],
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(timeSlot,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              if (slot.isNotEmpty)
                                Column(
                                  children: [
                                    Text(
                                        'Subject: ${slot['subject'] ?? 'Unknown'}'),
                                    Text(
                                        'Grade: ${slot['grade'] ?? 'Unknown'}'),
                                    Text('Learners: $learnerCount'),
                                    Text(
                                        'Selected: ${slot['learnerIds'] is String ? (slot['learnerIds'] as String).split(',').join(', ') : (slot['learnerIds'] as List<String>).join(', ')}'),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: role == 'teacher'
          ? FloatingActionButton(
              onPressed: () {
                _showAddTimetableDialog(
                    context, 0); // Default to first slot for FAB
              },
              child: const Icon(Icons.add),
              tooltip: 'Add Timetable Slot',
            )
          : null,
    );
  }

  String _getRangeLabel() {
    if (selectedDay.day == DateTime.now().day &&
        selectedDay.month == DateTime.now().month &&
        selectedDay.year == DateTime.now().year) {
      return 'Day';
    } else if (selectedDay.difference(DateTime.now()).inDays <= 7) {
      return 'Week';
    } else {
      return 'Month';
    }
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

class LearnerSelectionDialog extends StatefulWidget {
  final List<LearnerData> learners;

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
      title: const Text('Select Learners'),
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
                  if (value!)
                    selectedLearnerIds.add(learner.id);
                  else
                    selectedLearnerIds.remove(learner.id);
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, selectedLearnerIds),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
