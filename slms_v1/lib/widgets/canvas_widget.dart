import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf_render/pdf_render.dart';
import 'package:schoollms/services/database_service.dart';
import 'package:provider/provider.dart';
import 'package:vector_math/vector_math.dart' as vector;
import 'package:schoollms/models/asset.dart';
import 'package:schoollms/models/analytics.dart';
import 'package:schoollms/models/learnertimetable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:uuid/uuid.dart';

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

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'path': path,
        'pageIndex': pageIndex,
        'positionX': position.dx,
        'positionY': position.dy,
        'scale': scale,
      };
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

  factory Stroke.fromJson(Map<String, dynamic> json) {
    final points = (json['points'] as List<dynamic>?)
            ?.map((p) => ProtoPoint(p['x'] as double, p['y'] as double))
            .map((protoPoint) => Offset(protoPoint.x, protoPoint.y))
            .toList() ??
        [];
    return Stroke(
      points,
      Color(json['color'] as int? ?? 0xFF000000),
      json['strokeWidth'] as double? ?? 1.0,
    );
  }

  ProtoStroke toProto() {
    return ProtoStroke(
      points.map((offset) => ProtoPoint(offset.dx, offset.dy)).toList(),
      color.value,
      strokeWidth,
    );
  }
}

@immutable
class CanvasWidget extends StatefulWidget {
  final String learnerId;
  final String strokes; // JSON-encoded initial strokes
  final bool readOnly; // Parameter for read-only mode
  final VoidCallback onSave;
  final Function(Map<String, dynamic>) onUpdate;
  final List<CanvasAsset>? initialAssets; // Parameter for initial assets
  final Function(List<CanvasAsset>)?
      onAssetsUpdate; // Callback for asset updates
  final String? userRole; // New parameter for user role
  final String? timetableId; // Added to match all screens
  final String? slotId; // Added slotId parameter

  const CanvasWidget({
    Key? key,
    required this.learnerId,
    required this.strokes,
    this.readOnly = false,
    required this.onSave,
    required this.onUpdate,
    this.initialAssets,
    this.onAssetsUpdate,
    this.userRole, // Added userRole parameter
    this.timetableId, // Added
    this.slotId, // Added
  }) : super(key: key);

  @override
  State<CanvasWidget> createState() => _CanvasWidgetState();
}

class _CanvasWidgetState extends State<CanvasWidget> {
  late List<Stroke> _strokes;
  late List<CanvasAsset> _assets;
  Stroke? _currentStroke;
  vector.Matrix4 _transform = vector.Matrix4.identity();
  double _scale = 1.0;
  Offset _panOffset = Offset.zero;
  PdfDocument? _currentPdf;
  ui.Image? _currentImage;
  int _currentPageIndex = 0;
  String _status = 'active';
  String? _attendance;
  int? _attendanceDate;
  DateTime? _sessionStartTime;
  String? _deviceId;

  @override
  void initState() {
    super.initState();
    _strokes = _parseStrokes(widget.strokes);
    _assets = widget.initialAssets ?? [];
    _sessionStartTime = DateTime.now();
    _initializeDeviceId();
    _loadCanvasData();
    _loadLearnerTimetableData();
  }

  Future<void> _initializeDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Theme.of(context).platform == TargetPlatform.android) {
      final androidInfo = await deviceInfo.androidInfo;
      setState(() {
        _deviceId = androidInfo.id;
      });
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      final iosInfo = await deviceInfo.iosInfo;
      setState(() {
        _deviceId = iosInfo.identifierForVendor;
      });
    } else {
      setState(() {
        _deviceId = 'unknown_device_${widget.learnerId}';
      });
    }
  }

  List<Stroke> _parseStrokes(String strokesJson) {
    try {
      final List<dynamic> strokeData = jsonDecode(strokesJson);
      return strokeData.map((data) => Stroke.fromJson(data)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> _loadCanvasData() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final assets = await dbService.getAssetsByLearner(widget.learnerId);
    setState(() {
      _assets.addAll(assets.map((asset) => CanvasAsset(
            id: asset.id,
            type: asset.type,
            path: asset.data,
            pageIndex: 0,
            position: Offset(asset.positionX, asset.positionY),
            scale: asset.scale,
          )));
    });
  }

  Future<void> _loadLearnerTimetableData() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final timetables = await dbService.getLearnerTimetable(widget.learnerId,
        sinceTimestamp: 0);
    if (timetables.isNotEmpty) {
      final currentDate = DateTime.now().toIso8601String().split('T')[0];
      final timetable = timetables.firstWhere(
        (t) => t.timeSlot.contains(currentDate),
        orElse: () => timetables.first,
      );
      setState(() {
        _status = timetable.status ?? 'active';
        _attendance = timetable.attendance;
        _attendanceDate = timetable.attendanceDate;
      });
    }
  }

  void _startStroke(Offset position) {
    if (widget.readOnly) return;
    final localPosition = _transformPoint(position);
    setState(() {
      _currentStroke = Stroke(
        [localPosition],
        Colors.black,
        2.0,
      );
      if (_currentStroke != null) _strokes.add(_currentStroke!);
    });
  }

  void _updateStroke(Offset position) {
    if (widget.readOnly || _currentStroke == null) return;
    final localPosition = _transformPoint(position);
    setState(() {
      _currentStroke!.points.add(localPosition);
    });
  }

  void _endStroke() {
    if (widget.readOnly || _currentStroke == null) return;
    setState(() {
      _currentStroke = null;
    });
    _saveStrokes();
  }

  void _undo() {
    if (widget.readOnly || _strokes.isEmpty) return;
    setState(() {
      _strokes.removeLast();
    });
    _saveStrokes();
  }

  void _clear() {
    if (widget.readOnly) return;
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
    if (widget.readOnly) return;
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      final bytes = await pickedFile.readAsBytes();
      final image = await decodeImageFromList(bytes);
      setState(() {
        _currentImage = image;
        _currentPdf = null;
        _currentPageIndex = 0;
        final newAsset = CanvasAsset(
          id: Uuid().v4(),
          type: 'image',
          path: pickedFile.path,
          pageIndex: 0,
          position: Offset.zero,
          scale: 1.0,
        );
        _assets.add(newAsset);
        if (widget.onAssetsUpdate != null) {
          widget.onAssetsUpdate!([newAsset]);
        }
      });
      _saveAssets();
    }
  }

  Future<void> _pickPdf() async {
    if (widget.readOnly) return;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );
    if (result != null && result.files.isNotEmpty) {
      final pickedFile = result.files.first;
      final pdfDoc = await PdfDocument.openFile(pickedFile.path!);
      setState(() {
        _currentPdf = pdfDoc;
        _currentImage = null;
        _currentPageIndex = 0;
        final newAsset = CanvasAsset(
          id: Uuid().v4(),
          type: 'pdf',
          path: pickedFile.path!,
          pageIndex: 0,
          position: Offset.zero,
          scale: 1.0,
        );
        _assets.add(newAsset);
        if (widget.onAssetsUpdate != null) {
          widget.onAssetsUpdate!([newAsset]);
        }
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
      _updateAssetPage(pageIndex);
    });
  }

  void _nextPage() {
    if (widget.readOnly ||
        _currentPdf == null ||
        _currentPageIndex >= _currentPdf!.pageCount - 1) return;
    _renderPdfPage(_currentPageIndex + 1);
  }

  void _previousPage() {
    if (widget.readOnly || _currentPageIndex <= 0) return;
    _renderPdfPage(_currentPageIndex - 1);
  }

  void _updateAssetPage(int pageIndex) {
    setState(() {
      final assetIndex = _assets
          .indexWhere((a) => a.type == 'pdf' && a.path == _assets.last.path);
      if (assetIndex != -1) {
        final updatedAsset = _assets[assetIndex].copyWith(pageIndex: pageIndex);
        _assets[assetIndex] = updatedAsset;
        if (widget.onAssetsUpdate != null) {
          widget.onAssetsUpdate!([updatedAsset]);
        }
      }
    });
    _saveAssets();
  }

  Future<void> _saveStrokes() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    await dbService.saveStrokes(widget.learnerId, _strokes);
    await _saveLearnerTimetableData();
    widget.onSave();
    widget.onUpdate({'strokes': _strokes.map((s) => s.toJson()).toList()});
    _logAnalytics('stroke_update');
  }

  Future<void> _saveAssets() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    await dbService.saveAssets(
        widget.learnerId, _assets); // Pass List<CanvasAsset>
    await _saveLearnerTimetableData();
    widget.onSave();
    if (widget.onAssetsUpdate != null) {
      widget.onAssetsUpdate!(_assets);
    }
    _logAnalytics('asset_update');
  }

  Future<void> _saveLearnerTimetableData() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final timetables = await dbService.getLearnerTimetable(widget.learnerId,
        sinceTimestamp: 0);
    if (timetables.isNotEmpty) {
      final currentDate = DateTime.now().toIso8601String().split('T')[0];
      final timetable = timetables.firstWhere(
        (t) => t.timeSlot.contains(currentDate),
        orElse: () => timetables.first,
      );
      await dbService.updateLearnerTimetableStatus(
          widget.learnerId, timetable.id, _status);
      if (_attendance != null && _attendanceDate != null) {
        await dbService.recordAttendance(
            widget.learnerId, timetable.id, _attendance!, _attendanceDate!);
      }
    }
  }

  void _setStatus(String status) {
    if (widget.readOnly) return;
    setState(() {
      _status = status;
    });
    _saveLearnerTimetableData();
  }

  void _setAttendance(String attendance) {
    if (widget.readOnly) return;
    setState(() {
      _attendance = attendance;
      _attendanceDate = DateTime.now().millisecondsSinceEpoch;
    });
    _saveLearnerTimetableData();
  }

  Offset _transformPoint(Offset position) {
    final vector.Vector3 pointVector =
        vector.Vector3(position.dx, position.dy, 0);
    final matrix = _transform.clone()..invert();
    final transformedVector = matrix.transform3(pointVector);
    return Offset(transformedVector.x, transformedVector.y);
  }

  void _onScaleStart(ScaleStartDetails details) {
    setState(() {
      _panOffset = details.focalPoint;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    setState(() {
      _scale *= details.scale;
      _transform = vector.Matrix4.identity()
        ..scale(_scale)
        ..translate(details.focalPoint.dx - _panOffset.dx,
            details.focalPoint.dy - _panOffset.dy);
      _panOffset = details.focalPoint;
    });
  }

  Future<void> _logAnalytics(String action) async {
    if (_sessionStartTime == null || _deviceId == null) return;
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final endTime = DateTime.now();
    final timeSpent = endTime.difference(_sessionStartTime!).inSeconds;
    final analytics = Analytics(
      questionId: '', // To be set by parent if applicable
      learnerId: widget.learnerId,
      timeSpentSeconds: timeSpent,
      submissionStatus: action == 'stroke_update' ? 'draft' : 'asset_updated',
      deviceId: _deviceId!,
      timestamp: endTime.millisecondsSinceEpoch,
    );
    await dbService.insertAnalytics(analytics);
    _sessionStartTime = endTime; // Reset for next session
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = widget.userRole == 'admin';

    return Stack(
      children: [
        GestureDetector(
          onPanStart: widget.readOnly
              ? null
              : (details) => _startStroke(details.localPosition),
          onPanUpdate: widget.readOnly
              ? null
              : (details) => _updateStroke(details.localPosition),
          onPanEnd: widget.readOnly ? null : (details) => _endStroke(),
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
                onPressed: widget.readOnly ? null : _undo,
              ),
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: widget.readOnly ? null : _clear,
              ),
              IconButton(
                icon: const Icon(Icons.image),
                onPressed: widget.readOnly ? null : _pickImage,
              ),
              IconButton(
                icon: const Icon(Icons.picture_as_pdf),
                onPressed: widget.readOnly ? null : _pickPdf,
              ),
              if (_currentPdf != null) ...[
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: widget.readOnly ? null : _previousPage,
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: widget.readOnly ? null : _nextPage,
                ),
              ],
              const SizedBox(height: 10),
              DropdownButton<String>(
                value: _status,
                items: const [
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(value: 'absent', child: Text('Absent')),
                  DropdownMenuItem(value: 'pending', child: Text('Pending')),
                ],
                onChanged:
                    widget.readOnly ? null : (value) => _setStatus(value!),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check_circle),
                    onPressed: widget.readOnly
                        ? null
                        : () => _setAttendance('present'),
                    color: _attendance == 'present' ? Colors.green : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel),
                    onPressed:
                        widget.readOnly ? null : () => _setAttendance('absent'),
                    color: _attendance == 'absent' ? Colors.red : null,
                  ),
                  IconButton(
                    icon: const Icon(Icons.access_time),
                    onPressed:
                        widget.readOnly ? null : () => _setAttendance('late'),
                    color: _attendance == 'late' ? Colors.orange : null,
                  ),
                ],
              ),
              if (_attendance != null && _attendanceDate != null)
                Text(
                  'Attendance: $_attendance at ${DateTime.fromMillisecondsSinceEpoch(_attendanceDate!).toLocal()}',
                  style: const TextStyle(fontSize: 12),
                ),
              if (isAdmin)
                ElevatedButton(
                  onPressed: widget.readOnly ? null : _clear,
                  child: const Text('Admin Clear All'),
                ),
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
  final vector.Matrix4 transform;
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
    final Float64List transformMatrix = Float64List.fromList(transform.storage);
    canvas.transform(transformMatrix);

    // Draw assets (images/PDFs)
    for (final asset in assets) {
      if (asset.type == 'image' && currentImage != null) {
        final rect = Rect.fromLTWH(
          asset.position.dx,
          asset.position.dy,
          currentImage!.width * asset.scale,
          currentImage!.height * asset.scale,
        );
        canvas.drawImageRect(
          currentImage!,
          Rect.fromLTWH(0, 0, currentImage!.width.toDouble(),
              currentImage!.height.toDouble()),
          rect,
          Paint(),
        );
      } else if (asset.type == 'pdf' && currentImage != null) {
        final rect = Rect.fromLTWH(
          asset.position.dx,
          asset.position.dy,
          currentImage!.width * asset.scale,
          currentImage!.height * asset.scale,
        );
        canvas.drawImageRect(
          currentImage!,
          Rect.fromLTWH(0, 0, currentImage!.width.toDouble(),
              currentImage!.height.toDouble()),
          rect,
          Paint(),
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
