import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

abstract class CanvasElement {
  Map<String, dynamic> toJson();
}

class Stroke implements CanvasElement {
  final List<Offset> points;
  final Color color;
  final double strokeWidth; // Aligned with CanvasWidget

  Stroke({
    required this.points,
    this.color = Colors.black,
    this.strokeWidth = 2.0,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'stroke',
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'color': color.value,
      'strokeWidth': strokeWidth,
    };
  }

  static Stroke fromJson(Map<String, dynamic> json) {
    try {
      return Stroke(
        points: (json['points'] as List)
            .map((p) => Offset(p['x'] as double, p['y'] as double))
            .toList(),
        color: Color(json['color'] as int),
        strokeWidth: json['strokeWidth'] as double,
      );
    } catch (e) {
      throw Exception('Failed to parse Stroke from JSON: $e');
    }
  }
}

class ImageElement implements CanvasElement {
  final Uint8List data; // Base64-encoded image data
  final Offset position;
  final Size size;

  ImageElement({
    required this.data,
    required this.position,
    required this.size,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'image',
      'data': base64Encode(data),
      'position': {'x': position.dx, 'y': position.dy},
      'size': {'width': size.width, 'height': size.height},
    };
  }

  static ImageElement fromJson(Map<String, dynamic> json) {
    try {
      return ImageElement(
        data: base64Decode(json['data'] as String),
        position: Offset(
            json['position']['x'] as double, json['position']['y'] as double),
        size: Size(
            json['size']['width'] as double, json['size']['height'] as double),
      );
    } catch (e) {
      throw Exception('Failed to parse ImageElement from JSON: $e');
    }
  }
}

class AnnotationElement implements CanvasElement {
  final int pdfPage; // Links to a specific PDF page (one question per page)
  final List<Stroke> strokes;

  AnnotationElement({
    required this.pdfPage,
    required this.strokes,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'annotation',
      'pdfPage': pdfPage,
      'strokes': strokes.map((s) => s.toJson()).toList(),
    };
  }

  static AnnotationElement fromJson(Map<String, dynamic> json) {
    try {
      return AnnotationElement(
        pdfPage: json['pdfPage'] as int,
        strokes: (json['strokes'] as List)
            .map((s) => Stroke.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
    } catch (e) {
      throw Exception('Failed to parse AnnotationElement from JSON: $e');
    }
  }
}
