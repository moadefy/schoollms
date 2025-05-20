import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:schoollms/services/database_service.dart';
import 'package:provider/provider.dart';

// Placeholder for Protobuf-generated classes (generate from stroke.proto)
class ProtoPoint {
  final double x;
  final double y;
  ProtoPoint(this.x, this.y);

  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}

class ProtoStroke {
  final List<ProtoPoint> points;
  final int color;
  final double strokeWidth;
  ProtoStroke(this.points, this.color, this.strokeWidth);

  Map<String, dynamic> toJson() => {
        'points': points.map((p) => p.toJson()).toList(),
        'color': color,
        'strokeWidth': strokeWidth,
      };
}

// Class to represent an asset (image or PDF) on the canvas
class CanvasAsset {
  final String id;
  final String type; // 'image' or 'pdf'
  final String path;
  final int pageIndex;
  final Offset position;
  final double scale;

  CanvasAsset({
    required this.id,
    required this.type,
    required this.path,
    required this.pageIndex,
    required this.position,
    required this.scale,
  });

  CanvasAsset copyWith({
    String? id,
    String? type,
    String? path,
    int? pageIndex,
    Offset? position,
    double? scale,
  }) {
    return CanvasAsset(
      id: id ?? this.id,
      type: type ?? this.type,
      path: path ?? this.path,
      pageIndex: pageIndex ?? this.pageIndex,
      position: position ?? this.position,
      scale: scale ?? this.scale,
    );
  }
}

class Stroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  Stroke(this.points, this.color, this.strokeWidth);

  Map<String, dynamic> toJson() {
    return {
      'points': points.map((p) => ProtoPoint(p.dx, p.dy).toJson()).toList(),
      'color': color.value,
      'strokeWidth': strokeWidth,
    };
  }
}

@immutable
class CanvasWidget extends StatefulWidget {
  final String learnerId;
  final VoidCallback onSave;
  final Function(Map<String, dynamic>) onUpdate;

  const CanvasWidget({
    Key? key,
    required this.learnerId,
    required this.onSave,
    required this.onUpdate,
  }) : super(key: key);

  @override
  State<CanvasWidget> createState() => _CanvasWidgetState();
}

class _CanvasWidgetState extends State<CanvasWidget> {
  final List<Stroke> _strokes = [];
  final List<CanvasAsset> _assets = [];
  Stroke? _currentStroke;
  Matrix4 _transform = Matrix4.identity();
  double _scale = 1.0;
  Offset _panOffset = Offset.zero;
  PdfDocument? _currentPdf;
  ui.Image? _currentImage;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadCanvasData();
  }

  Future<void> _loadCanvasData() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final strokesData = await dbService.fetchStrokes(widget.learnerId);
    final assetsData = await dbService.getAssets(widget.learnerId);

    setState(() {
      _strokes.addAll(strokesData.map((data) => Stroke(
            (data['points'] as List)
                .map((p) => Offset(p['x'], p['y']))
                .toList(),
            Color(data['color']),
            data['strokeWidth'],
          )));
      _assets.addAll(assetsData.map((data) => CanvasAsset(
            id: data['id'],
            type: data['type'],
            path: data['path'],
            pageIndex: data['pageIndex'],
            position: Offset(data['positionX'], data['positionY']),
            scale: data['scale'],
          )));
    });
  }

  void _startStroke(Offset position) {
    final localPosition = _transformPoint(position);
    setState(() {
      _currentStroke = Stroke(
        [localPosition],
        Colors.black, // Use theme color if needed
        2.0,
      );
      _strokes.add(_currentStroke!);
    });
  }

  void _updateStroke(Offset position) {
    if (_currentStroke == null) return;
    final localPosition = _transformPoint(position);
    setState(() {
      _currentStroke!.points.add(localPosition);
    });
  }

  void _endStroke() {
    if (_currentStroke == null) return;
    setState(() {
      _currentStroke = null;
    });
    _saveStrokes();
  }

  void _undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
      _saveStrokes();
    }
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _assets.clear();
      _currentPdf = null;
      _currentImage = null;
      _currentPageIndex = 0;
    });
    _saveStrokes();
    _saveAssets();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final image = await decodeImageFromList(bytes);
      setState(() {
        _currentImage = image;
        _currentPdf = null;
        _currentPageIndex = 0;
        _assets.add(CanvasAsset(
          id: DateTime.now().toString(),
          type: 'image',
          path: pickedFile.path,
          pageIndex: 0,
          position: Offset.zero,
          scale: 1.0,
        ));
      });
      _saveAssets();
    }
  }

  Future<void> _pickPdf() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
        source: ImageSource.gallery); // Adjust for file picker if needed
    if (pickedFile != null) {
      final pdfDoc = await PdfDocument.openFile(pickedFile.path);
      setState(() {
        _currentPdf = pdfDoc;
        _currentImage = null;
        _currentPageIndex = 0;
        _assets.add(CanvasAsset(
          id: DateTime.now().toString(),
          type: 'pdf',
          path: pickedFile.path,
          pageIndex: 0,
          position: Offset.zero,
          scale: 1.0,
        ));
      });
      _saveAssets();
    }
  }

  Future<void> _renderPdfPage(int pageIndex) async {
    if (_currentPdf == null) return;
    final page = await _currentPdf!.getPage(pageIndex + 1);
    final pageImage = await page.render();
    final image = await pageImage.createImageIfNotAvailable();
    setState(() {
      _currentImage = image;
      _currentPageIndex = pageIndex;
    });
  }

  void _nextPage() {
    if (_currentPdf == null || _currentPageIndex >= _currentPdf!.pageCount - 1)
      return;
    _renderPdfPage(_currentPageIndex + 1);
    _updateAssetPage(_currentPageIndex + 1);
  }

  void _previousPage() {
    if (_currentPageIndex <= 0) return;
    _renderPdfPage(_currentPageIndex - 1);
    _updateAssetPage(_currentPageIndex - 1);
  }

  void _updateAssetPage(int pageIndex) {
    setState(() {
      final assetIndex = _assets
          .indexWhere((a) => a.type == 'pdf' && a.path == _assets.last.path);
      if (assetIndex != -1) {
        _assets[assetIndex] =
            _assets[assetIndex].copyWith(pageIndex: pageIndex);
      }
    });
    _saveAssets();
  }

  void _saveStrokes() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    await dbService.saveStrokes(widget.learnerId, _strokes);
    widget.onSave();
    widget.onUpdate({'strokes': _strokes.map((s) => s.toJson()).toList()});
  }

  void _saveAssets() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    await dbService.saveAssets(widget.learnerId, _assets);
    widget.onSave();
  }

  Offset _transformPoint(Offset position) {
    final matrix = _transform.clone()..invert();
    final vector = matrix.transform3(Vector3(position.dx, position.dy, 0));
    return Offset(vector.x, vector.y);
  }

  void _onScaleStart(ScaleStartDetails details) {
    setState(() {
      _panOffset = details.focalPoint;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale *= details.scale;
      _transform = Matrix4.identity()
        ..scale(_scale)
        ..translate(details.focalPoint.dx - _panOffset.dx,
            details.focalPoint.dy - _panOffset.dy);
      _panOffset = details.focalPoint;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        GestureDetector(
          onPanStart: (details) => _startStroke(details.localPosition),
          onPanUpdate: (details) => _updateStroke(details.localPosition),
          onPanEnd: (details) => _endStroke(),
          onScaleStart: _onScaleStart,
          onScaleUpdate: _onScaleUpdate,
          child: CustomPaint(
            painter: CanvasPainter(
              strokes: _strokes,
              assets: _assets,
              transform: _transform,
              currentImage: _currentImage,
            ),
            child: Container(),
          ),
        ),
        Positioned(
          top: 10,
          right: 10,
          child: Column(
            children: [
              IconButton(
                icon: const Icon(Icons.undo),
                onPressed: _undo,
              ),
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: _clear,
              ),
              IconButton(
                icon: const Icon(Icons.image),
                onPressed: _pickImage,
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: _pickPdf,
              ),
              if (_currentPdf != null) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: _previousPage,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: _nextPage,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class CanvasPainter extends CustomPainter {
  final List<Stroke> strokes;
  final List<CanvasAsset> assets;
  final Matrix4 transform;
  final ui.Image? currentImage;

  CanvasPainter({
    required this.strokes,
    required this.assets,
    required this.transform,
    required this.currentImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.transform(transform.storage);

    // Draw assets (images/PDFs)
    for (final asset in assets) {
      if (asset.type == 'image' && currentImage != null) {
        final paint = Paint();
        canvas.drawImage(
          currentImage!,
          asset.position,
          paint,
        );
      } else if (asset.type == 'pdf' && currentImage != null) {
        final paint = Paint();
        canvas.drawImage(
          currentImage!,
          asset.position,
          paint,
        );
      }
    }

    // Draw strokes
    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..style = PaintingStyle.stroke;
      final path = Path();
      if (stroke.points.isNotEmpty) {
        path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (final point in stroke.points.skip(1)) {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawPath(path, paint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
