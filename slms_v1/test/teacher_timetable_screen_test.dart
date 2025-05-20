import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:school_app/screens/timetable/teacher_timetable_screen.dart';
import 'package:school_app/services/database_service.dart';
import 'package:mockito/mockito.dart';

class MockDatabaseService extends Mock implements DatabaseService {}

void main() {
  testWidgets('TeacherTimetableScreen adds timetable',
      (WidgetTester tester) async {
    final mockDb = MockDatabaseService();
    when(mockDb.getTimetables(any)).thenAnswer((_) async => []);
    when(mockDb._db.query('classes', where: 'teacherId = ?', whereArgs: [any]))
        .thenAnswer((_) async => [
              {
                'id': 'class_1',
                'teacherId': 'teacher_1',
                'subject': 'Math',
                'grade': '10'
              }
            ]);
    when(mockDb.getLearnersByGrade('10')).thenAnswer(
        (_) async => [Learner(id: 'learner_1', name: 'Alice', grade: '10')]);

    await tester.pumpWidget(
      MaterialApp(
        home: Provider<DatabaseService>.value(
          value: mockDb,
          child: TeacherTimetableScreen(teacherId: 'teacher_1'),
        ),
      ),
    );

    await tester.tap(find.byType(Container).first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select Class'));
    await tester.tap(find.text('Math (Grade 10)').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Select Learners (0)'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Alice'));
    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.byType(SnackBar), findsOneWidget);
  });
}
