import 'package:flutter_test/flutter_test.dart';
import 'package:schoollms/widgets/canvas_widget.dart';
import 'package:schoollms/models/asset.dart';
import 'dart:convert';

void main() {
  group('Canvas Widget Tests', () {
    test('Serialize and deserialize stroke data', () {
      final stroke = Stroke(
        points: [Offset(10, 20), Offset(30, 40)],
        color: Colors.red,
        width: 5.0,
      );
      final json = jsonEncode({
        'strokes': [stroke.toJson()],
        'assets': []
      });
      final decoded = jsonDecode(json);
      final restoredStroke = Stroke.fromJson(decoded['strokes'][0]);
      expect(restoredStroke.points, stroke.points);
      expect(restoredStroke.color, stroke.color);
      expect(restoredStroke.width, stroke.width);
    });

    test('Serialize and deserialize asset data', () {
      final asset = Asset(
        id: 'asset_1',
        type: 'image',
        data: 'base64data',
        position: Offset(50, 60),
        pageIndex: 0,
      );
      final json = jsonEncode({
        'strokes': [],
        'assets': [asset.toJson()]
      });
      final decoded = jsonDecode(json);
      final restoredAsset = Asset.fromJson(decoded['assets'][0]);
      expect(restoredAsset.id, asset.id);
      expect(restoredAsset.type, asset.type);
      expect(restoredAsset.data, asset.data);
      expect(restoredAsset.position, asset.position);
      expect(restoredAsset.pageIndex, asset.pageIndex);
    });

    test('Undo and redo functionality', () {
      var savedData = '';
      Analytics? savedAnalytics;
      final widget = CanvasWidget(
        initialData: jsonEncode({'strokes': [], 'assets': []}),
        onChanged: (data, analytics) {
          savedData = data;
          savedAnalytics = analytics;
        },
      );
      final state = widget.createState();
      state._strokes.add(Stroke(points: [Offset(10, 20)]));
      state._addToHistory();
      state._strokes.add(Stroke(points: [Offset(30, 40)]));
      state._addToHistory();
      state._undo();
      expect(state._strokes.length, 1);
      expect(state._strokes[0].points, [Offset(10, 20)]);
      state._redo();
      expect(state._strokes.length, 2);
      expect(state._strokes[1].points, [Offset(30, 40)]);
    });

    test('Canvas size warning', () {
      var savedData = '';
      Analytics? savedAnalytics;
      final widget = CanvasWidget(
        initialData: jsonEncode({'strokes': [], 'assets': []}),
        onChanged: (data, analytics) {
          savedData = data;
          savedAnalytics = analytics;
        },
      );
      final state = widget.createState();
      for (int i = 0; i < 10000; i++) {
        state._strokes.add(Stroke(
            points:
                List.generate(100, (j) => Offset(j.toDouble(), j.toDouble()))));
      }
      state._checkCanvasSize();
      expect(state._showWarning, true);
    });

    test('Analytics generation', () {
      var savedData = '';
      Analytics? savedAnalytics;
      final widget = CanvasWidget(
        initialData: jsonEncode({'strokes': [], 'assets': []}),
        onChanged: (data, analytics) {
          savedData = data;
          savedAnalytics = analytics;
        },
      );
      final state = widget.createState();
      state._strokes.add(Stroke(points: [Offset(50, 50), Offset(60, 60)]));
      state._assets.add(Asset(
          id: 'asset_1',
          type: 'image',
          data: 'base64data',
          position: Offset.zero,
          pageIndex: 0));
      state._saveCanvas();
      expect(savedAnalytics?.strokeCount, 1);
      expect(savedAnalytics?.assetCount, 1);
      expect(savedAnalytics?.drawingTime, greaterThan(0));
      final heatmap = jsonDecode(savedAnalytics!.heatmap);
      expect(heatmap[0][0], greaterThan(0));
    });
  });
}
