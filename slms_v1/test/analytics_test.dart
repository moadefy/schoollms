import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:schoollms/services/database_service.dart';
import 'package:schoollms/models/analytics.dart';
import 'dart:convert';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Analytics Tests', () {
    DatabaseService dbService;
    Database db;

    setUp() async {
      db = await openDatabase(inMemoryDatabasePath);
      dbService = DatabaseService().._db = db;
      await dbService.init();
    });

    tearDown() async {
      await db.close();
    });

    test('Insert and retrieve analytics', () async {
      final analytics = Analytics(
        id: 'analytics_1',
        questionId: 'question_1',
        learnerId: 'learner_1',
        strokeCount: 10,
        drawingTime: 5000,
        assetCount: 2,
        heatmap: jsonEncode(List.generate(10, (_) => List.filled(10, 1))),
      );
      await dbService.insertAnalytics(analytics);

      final retrieved = await dbService.getAnalyticsByQuestion('question_1');
      expect(retrieved.length, 1);
      expect(retrieved[0].strokeCount, 10);
      expect(retrieved[0].drawingTime, 5000);
      expect(retrieved[0].assetCount, 2);
      expect(jsonDecode(retrieved[0].heatmap), List.generate(10, (_) => List.filled(10, 1)));
    });

    test('Heatmap generation accuracy', () async {
      final widget = CanvasWidget(
        initialData: jsonEncode({'strokes': [], 'assets': []}),
        onChanged: (data, analytics) async {
          expect(analytics!.strokeCount, 1);
          expect(analytics!.assetCount, 0);
          expect(analytics!.drawingTime, greaterThan(0));
          final heatmap = jsonDecode(analytics.heatmap);
          expect(heatmap[0][0], greaterThan(0)); // Stroke at (50, 50)
        },
      );
      final state = widget.createState();
      state._strokes.add(Stroke(points: [Offset(50, 50), Offset(60, 60)]));
      state._saveCanvas();
    });
  });
}