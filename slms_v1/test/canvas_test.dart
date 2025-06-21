import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:schoollms/models/timetable.dart';
import 'package:schoollms/services/database_service.dart';
import 'package:schoollms/widgets/canvas_widget.dart';
import 'canvas_test.mocks.dart';

// Generate mocks with: flutter pub run build_runner build
@GenerateMocks([DatabaseService])
void main() {
  late MockDatabaseService mockDbService;
  late VoidCallback onSaveCallback;
  late Function(Map<String, dynamic>) onUpdateCallback;

  setUp(() async {
    mockDbService = MockDatabaseService();
    onSaveCallback = () {};
    onUpdateCallback = (Map<String, dynamic> data) {};

    // Mock database methods
    when(mockDbService.getStrokes(any)).thenAnswer((_) async => []);
    when(mockDbService.getAssets(any)).thenAnswer((_) async => []);
    when(mockDbService.saveStrokes(any, any)).thenAnswer((_) async {});
    when(mockDbService.saveAssets(any, any)).thenAnswer((_) async {});
  });

  tearDown(() {
    reset(mockDbService);
  });

  group('CanvasWidget Tests', () {
    testWidgets('CanvasWidget loads strokes and assets',
        (WidgetTester tester) async {
      // Arrange
      final strokes = [
        {
          'points': [
            {'x': 10.0, 'y': 10.0},
            {'x': 20.0, 'y': 20.0},
          ],
          'color': Colors.black.value,
          'strokeWidth': 2.0,
        }
      ];
      final assets = [
        {
          'id': 'asset1',
          'type': 'image',
          'path': 'path/to/image.png',
          'pageIndex': 0,
          'positionX': 0.0,
          'positionY': 0.0,
          'scale': 1.0,
        }
      ];

      when(mockDbService.getStrokes('learner_1'))
          .thenAnswer((_) async => strokes);
      when(mockDbService.getAssets('learner_1'))
          .thenAnswer((_) async => assets);

      // Act
      await tester.pumpWidget(
        Provider<DatabaseService>(
          create: (_) => mockDbService,
          child: MaterialApp(
            home: CanvasWidget(
              learnerId: 'learner_1',
              onSave: onSaveCallback,
              onUpdate: onUpdateCallback,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('CanvasWidget saves strokes on draw',
        (WidgetTester tester) async {
      // Arrange
      await tester.pumpWidget(
        Provider<DatabaseService>(
          create: (_) => mockDbService,
          child: MaterialApp(
            home: CanvasWidget(
              learnerId: 'learner_1',
              onSave: onSaveCallback,
              onUpdate: onUpdateCallback,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Act: Simulate drawing
      await tester.drag(find.byType(CustomPaint), const Offset(10, 10));
      await tester.pumpAndSettle();

      // Assert: Verify saveStrokes was called
      verify(mockDbService.saveStrokes('learner_1', any)).called(1);
    });

    testWidgets('CanvasWidget integrates with timetable, question, and answer',
        (WidgetTester tester) async {
      // Arrange
      final timetable = Timetable(
        id: 't1',
        teacherId: 'teacher_1',
        learnerId: 'learner_1',
        subject: 'Math',
        startTime: DateTime.now(),
        endTime: DateTime.now().add(const Duration(hours: 1)),
      );
      final question = Question(
        id: 'q1',
        timetableId: 't1',
        content: 'Solve 2 + 2',
        pageIndex: 0,
      );
      final answer = Answer(
        id: 'a1',
        questionId: 'q1',
        learnerId: 'learner_1',
        strokes: [],
        assets: [],
      );

      await mockDbService.saveTimetable(timetable);
      await mockDbService.saveQuestion(question);
      await mockDbService.saveAnswer(answer);

      when(mockDbService.getTimetable('t1')).thenAnswer((_) async => timetable);
      when(mockDbService.getQuestion('q1')).thenAnswer((_) async => question);
      when(mockDbService.getAnswer('a1')).thenAnswer((_) async => answer);

      // Act
      await tester.pumpWidget(
        Provider<DatabaseService>(
          create: (_) => mockDbService,
          child: MaterialApp(
            home: CanvasWidget(
              learnerId: 'learner_1',
              onSave: onSaveCallback,
              onUpdate: onUpdateCallback,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Assert
      expect(find.byType(CanvasWidget), findsOneWidget);
      verify(mockDbService.getStrokes('learner_1')).called(1);
      verify(mockDbService.getAssets('learner_1')).called(1);
    });
  });
}
