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

// Placeholder for Protobuf-generated classes
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

class CanvasAsset {
  final String id;
  final String type;
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
            ?.map((p) => ProtoPoint(p['x'] as double, p['y' as double]))
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
  final String strokes; // JSON-encoded initial strokes per page
  final bool readOnly;
  final VoidCallback onSave;
  final Function(Map<String, dynamic>) onUpdate;
  final List<CanvasAsset>? initialAssets;
  final Function(List<CanvasAsset>)? onAssetsUpdate;
  final String? userRole;
  final String? timetableId;
  final String? slotId;

  const CanvasWidget({
    Key? key,
    required this.learnerId,
    required this.strokes,
    this.readOnly = false,
    required this.onSave,
    required this.onUpdate,
    this.initialAssets,
    this.onAssetsUpdate,
    this.userRole,
    this.timetableId,
    this.slotId,
  }) : super(key: key);

  @override
  State<CanvasWidget> createState() => _CanvasWidgetState();
}

class _CanvasWidgetState extends State<CanvasWidget> {
  late Map<int, List<Stroke>> _strokesPerPage; // Strokes per page
  late List<CanvasAsset> _assets;
  Stroke? _currentStroke;
  vector.Matrix4 _transform = vector.Matrix4.identity();
  double _scale = 1.0;
  Offset _panOffset = Offset.zero;
  PdfDocument? _currentPdf;
  ui.Image? _currentImage;
  int _currentPageIndex = 0;
  double _strokeWidth = 2.0;
  Color _strokeColor = Colors.black;
  String _status = 'active';
  String? _attendance;
  int? _attendanceDate;
  DateTime? _sessionStartTime;
  String? _deviceId;
  bool _showPagePreview = false;

  @override
  void initState() {
    super.initState();
    _strokesPerPage = _parseStrokes(widget.strokes);
    _assets = widget.initialAssets ?? [];
    _sessionStartTime = DateTime.now();
    _loadCanvasData();
    _loadLearnerTimetableData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _initializeDeviceId();
  }

  Future<void> _initializeDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    if (Theme.of(context).platform == TargetPlatform.android) {
      final androidInfo = await deviceInfo.androidInfo;
      setState(() => _deviceId = androidInfo.id);
    } else if (Theme.of(context).platform == TargetPlatform.iOS) {
      final iosInfo = await deviceInfo.iosInfo;
      setState(() => _deviceId = iosInfo.identifierForVendor);
    } else {
      setState(() => _deviceId = 'unknown_device_${widget.learnerId}');
    }
  }

  Map<int, List<Stroke>> _parseStrokes(String strokesJson) {
    try {
      final Map<String, dynamic> strokeData = jsonDecode(strokesJson);
      return strokeData.map((key, value) => MapEntry(
            int.parse(key),
            (value as List<dynamic>)
                .map((data) => Stroke.fromJson(data))
                .toList(),
          ));
    } catch (e) {
      return {_currentPageIndex: []};
    }
  }

  Future<void> _loadCanvasData() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final assets = await dbService.getAssetsByLearner(widget.learnerId);
    setState(() => _assets.addAll(assets.map((asset) => CanvasAsset(
          id: asset.id,
          type: asset.type,
          path: asset.data,
          pageIndex: 0,
          position: Offset(asset.positionX, asset.positionY),
          scale: asset.scale,
        ))));
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

  void _handleScaleStart(ScaleStartDetails details) {
    if (widget.readOnly) return;
    final localPosition = _transformPoint(details.localFocalPoint);
    setState(() => _panOffset = details.localFocalPoint);
    if (details.pointerCount == 1) {
      // Single touch: start drawing
      setState(() {
        _currentStroke = Stroke([localPosition], _strokeColor, _strokeWidth);
        if (_currentStroke != null)
          _strokesPerPage
              .putIfAbsent(_currentPageIndex, () => [])
              .add(_currentStroke!);
      });
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (widget.readOnly) return;
    if (details.pointerCount == 1) {
      // Single touch: update drawing
      if (_currentStroke != null) {
        final localPosition = _transformPoint(details.localFocalPoint);
        setState(() => _currentStroke!.points.add(localPosition));
      }
    } else {
      // Multi-touch: pan (scroll)
      setState(() {
        _transform.translate(
          details.localFocalPoint.dx - _panOffset.dx,
          details.localFocalPoint.dy - _panOffset.dy,
        );
        _panOffset = details.localFocalPoint;
      });
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    if (widget.readOnly || _currentStroke == null) return;
    if (details.pointerCount == 1) {
      // Single touch: end drawing
      setState(() => _currentStroke = null);
      _saveStrokes();
    }
  }

  void _zoomIn() {
    if (widget.readOnly) return;
    setState(() {
      _scale *= 1.2;
      _transform.scale(1.2);
    });
  }

  void _zoomOut() {
    if (widget.readOnly) return;
    setState(() {
      _scale /= 1.2;
      _transform.scale(1 / 1.2);
    });
  }

  void _addPage() {
    if (widget.readOnly) return;
    setState(() {
      _currentPageIndex = _strokesPerPage.keys.isEmpty
          ? 0
          : _strokesPerPage.keys.reduce((a, b) => a > b ? a : b) + 1;
      _strokesPerPage[_currentPageIndex] = [];
    });
    _saveStrokes();
  }

  void _navigateToPage(int pageIndex) {
    if (widget.readOnly) return;
    setState(() => _currentPageIndex = pageIndex);
    if (_currentPdf != null) _renderPdfPage(pageIndex);
  }

  void _undo() {
    if (widget.readOnly || _strokesPerPage[_currentPageIndex]!.isEmpty ?? true)
      return;
    setState(() => _strokesPerPage[_currentPageIndex]!.removeLast());
    _saveStrokes();
  }

  void _clear() {
    if (widget.readOnly) return;
    setState(() {
      _strokesPerPage[_currentPageIndex] = [];
      _assets.removeWhere((a) => a.pageIndex == _currentPageIndex);
      _currentPdf = null;
      _currentImage = null;
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
        final newAsset = CanvasAsset(
          id: const Uuid().v4(),
          type: 'image',
          path: pickedFile.path,
          pageIndex: _currentPageIndex,
          position: Offset.zero,
          scale: 1.0,
        );
        _assets.add(newAsset);
        if (widget.onAssetsUpdate != null) widget.onAssetsUpdate!([newAsset]);
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
        _renderPdfPage(_currentPageIndex);
        final newAsset = CanvasAsset(
          id: const Uuid().v4(),
          type: 'pdf',
          path: pickedFile.path!,
          pageIndex: _currentPageIndex,
          position: Offset.zero,
          scale: 1.0,
        );
        _assets.add(newAsset);
        if (widget.onAssetsUpdate != null) widget.onAssetsUpdate!([newAsset]);
      });
      _saveAssets();
    }
  }

  Future<void> _renderPdfPage(int pageIndex) async {
    if (_currentPdf == null) return;
    final page = await _currentPdf!.getPage(pageIndex + 1);
    final pageImage = await page.render();
    final image = await pageImage.createImageIfNotAvailable();
    setState(() => _currentImage = image);
  }

  void _updateAssetPage(int pageIndex) {
    setState(() {
      final assetIndex = _assets.indexWhere((a) =>
          a.type == 'pdf' &&
          a.path == _assets.lastWhere((a) => a.type == 'pdf').path);
      if (assetIndex != -1) {
        final updatedAsset = _assets[assetIndex].copyWith(pageIndex: pageIndex);
        _assets[assetIndex] = updatedAsset;
        if (widget.onAssetsUpdate != null)
          widget.onAssetsUpdate!([updatedAsset]);
      }
    });
    _saveAssets();
  }

  Future<void> _saveStrokes() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    await dbService.saveStrokes(
        widget.learnerId,
        _strokesPerPage.map((key, value) =>
                MapEntry(key.toString(), value.map((s) => s.toJson()).toList()))
            as List<Stroke>);
    await _saveLearnerTimetableData();
    widget.onSave();
    widget.onUpdate({
      'strokes': _strokesPerPage.map(
          (k, v) => MapEntry(k.toString(), v.map((s) => s.toJson()).toList()))
    });
    _logAnalytics('stroke_update');
  }

  Future<void> _saveAssets() async {
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    await dbService.saveAssets(widget.learnerId, _assets);
    await _saveLearnerTimetableData();
    widget.onSave();
    if (widget.onAssetsUpdate != null) widget.onAssetsUpdate!(_assets);
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
    setState(() => _status = status);
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

  Future<void> _logAnalytics(String action) async {
    if (_sessionStartTime == null || _deviceId == null) return;
    final dbService = Provider.of<DatabaseService>(context, listen: false);
    final endTime = DateTime.now();
    final timeSpent = endTime.difference(_sessionStartTime!).inSeconds;
    final analytics = Analytics(
      questionId: '',
      learnerId: widget.learnerId,
      timeSpentSeconds: timeSpent,
      submissionStatus: action == 'stroke_update' ? 'draft' : 'asset_updated',
      deviceId: _deviceId!,
      timestamp: endTime.millisecondsSinceEpoch,
      timetableId: widget.timetableId,
      slotId: widget.slotId,
    );
    await dbService.insertAnalytics(analytics);
    _sessionStartTime = endTime;
  }

  @override
  Widget build(BuildContext context) {
    bool isAdmin = widget.userRole == 'admin';

    return Column(
      children: [
        if (_showPagePreview)
          Container(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _strokesPerPage.length,
              itemBuilder: (context, index) {
                final page = _strokesPerPage.keys.elementAt(index);
                return GestureDetector(
                  onTap: () => _navigateToPage(page),
                  child: Container(
                    width: 80,
                    margin: EdgeInsets.all(4),
                    color: _currentPageIndex == page ? Colors.grey[300] : null,
                    child: Center(child: Text('Page $page')),
                  ),
                );
              },
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              GestureDetector(
                onScaleStart: _handleScaleStart,
                onScaleUpdate: _handleScaleUpdate,
                onScaleEnd: _handleScaleEnd,
                child: CustomPaint(
                  painter: CanvasPainter(
                    strokes: _strokesPerPage[_currentPageIndex] ?? [],
                    assets: _assets
                        .where((a) => a.pageIndex == _currentPageIndex)
                        .toList(),
                    transform: _transform,
                    currentImage: _currentImage,
                  ),
                  child: Container(),
                ),
              ),
              Positioned(
                top: 10,
                left: 10,
                child: Row(
                  children: [
                    DropdownButton<double>(
                      value: _strokeWidth,
                      items: [1.0, 2.0, 4.0, 6.0]
                          .map((width) => DropdownMenuItem(
                              value: width, child: Text('${width.toInt()}px')))
                          .toList(),
                      onChanged: widget.readOnly
                          ? null
                          : (value) => setState(() => _strokeWidth = value!),
                    ),
                    SizedBox(width: 10),
                    DropdownButton<Color>(
                      value: _strokeColor,
                      items: [
                        Colors.black,
                        Colors.red,
                        Colors.blue,
                        Colors.green
                      ]
                          .map((color) => DropdownMenuItem(
                              value: color,
                              child: Container(
                                  width: 20, height: 20, color: color)))
                          .toList(),
                      onChanged: widget.readOnly
                          ? null
                          : (value) => setState(() => _strokeColor = value!),
                    ),
                    SizedBox(width: 10),
                    IconButton(
                        icon: Icon(Icons.zoom_in),
                        onPressed: widget.readOnly ? null : _zoomIn),
                    IconButton(
                        icon: Icon(Icons.zoom_out),
                        onPressed: widget.readOnly ? null : _zoomOut),
                    IconButton(
                        icon: Icon(Icons.add),
                        onPressed: widget.readOnly ? null : _addPage),
                    IconButton(
                        icon: Icon(Icons.list),
                        onPressed: () => setState(
                            () => _showPagePreview = !_showPagePreview)),
                  ],
                ),
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Column(
                  children: [
                    IconButton(
                        icon: const Icon(Icons.undo),
                        onPressed: widget.readOnly ? null : _undo),
                    IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: widget.readOnly ? null : _clear),
                    IconButton(
                        icon: const Icon(Icons.image),
                        onPressed: widget.readOnly ? null : _pickImage),
                    IconButton(
                        icon: const Icon(Icons.picture_as_pdf),
                        onPressed: widget.readOnly ? null : _pickPdf),
                    if (_currentPdf != null) ...[
                      IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: widget.readOnly
                              ? null
                              : () => _renderPdfPage(_currentPageIndex - 1)),
                      IconButton(
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: widget.readOnly
                              ? null
                              : () => _renderPdfPage(_currentPageIndex + 1)),
                    ],
                    const SizedBox(height: 10),
                    DropdownButton<String>(
                      value: _status,
                      items: const [
                        DropdownMenuItem(
                            value: 'active', child: Text('Active')),
                        DropdownMenuItem(
                            value: 'absent', child: Text('Absent')),
                        DropdownMenuItem(
                            value: 'pending', child: Text('Pending')),
                      ],
                      onChanged: widget.readOnly
                          ? null
                          : (value) => _setStatus(value!),
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
                            color:
                                _attendance == 'present' ? Colors.green : null),
                        IconButton(
                            icon: const Icon(Icons.cancel),
                            onPressed: widget.readOnly
                                ? null
                                : () => _setAttendance('absent'),
                            color: _attendance == 'absent' ? Colors.red : null),
                        IconButton(
                            icon: const Icon(Icons.access_time),
                            onPressed: widget.readOnly
                                ? null
                                : () => _setAttendance('late'),
                            color:
                                _attendance == 'late' ? Colors.orange : null),
                      ],
                    ),
                    if (_attendance != null && _attendanceDate != null)
                      Text(
                          'Attendance: $_attendance at ${DateTime.fromMillisecondsSinceEpoch(_attendanceDate!).toLocal()}',
                          style: const TextStyle(fontSize: 12)),
                    if (isAdmin)
                      ElevatedButton(
                          onPressed: widget.readOnly ? null : _clear,
                          child: const Text('Admin Clear All')),
                  ],
                ),
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

    for (final asset in assets) {
      if (asset.type == 'image' && currentImage != null) {
        final rect = Rect.fromLTWH(
            asset.position.dx,
            asset.position.dy,
            currentImage!.width * asset.scale,
            currentImage!.height * asset.scale);
        canvas.drawImageRect(
            currentImage!,
            Rect.fromLTWH(0, 0, currentImage!.width.toDouble(),
                currentImage!.height.toDouble()),
            rect,
            Paint());
      } else if (asset.type == 'pdf' && currentImage != null) {
        final rect = Rect.fromLTWH(
            asset.position.dx,
            asset.position.dy,
            currentImage!.width * asset.scale,
            currentImage!.height * asset.scale);
        canvas.drawImageRect(
            currentImage!,
            Rect.fromLTWH(0, 0, currentImage!.width.toDouble(),
                currentImage!.height.toDouble()),
            rect,
            Paint());
      }
    }

    for (final stroke in strokes) {
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth
        ..style = PaintingStyle.stroke;
      final path = Path();
      if (stroke.points.isNotEmpty) {
        path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
        for (final point in stroke.points.skip(1))
          path.lineTo(point.dx, point.dy);
        canvas.drawPath(path, paint);
      }
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
