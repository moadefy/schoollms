import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';

abstract class CanvasElement {
  Map<String, dynamic> toJson();
}

class Stroke implements CanvasElement {
  final List<Offset> points;
  final Color color;
  final double width;

  Stroke({required this.points, this.color = Colors.black, this.width = 2.0});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'stroke',
        'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        'color': color.value,
        'width': width,
      };

  static Stroke fromJson(Map<String, dynamic> json) {
    return Stroke(
      points: (json['points'] as List)
          .map((p) => Offset(p['x'].toDouble(), p['y'].toDouble()))
          .toList(),
      color: Color(json['color']),
      width: json['width'].toDouble(),
    );
  }
}

class ImageElement implements CanvasElement {
  final Uint8List data; // Base64-encoded image
  final Offset position;
  final Size size;

  ImageElement(
      {required this.data, required this.position, required this.size});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'image',
        'data': base64Encode(data),
        'position': {'x': position.dx, 'y': position.dy},
        'size': {'width': size.width, 'height': size.height},
      };

  static ImageElement fromJson(Map<String, dynamic> json) {
    return ImageElement(
      data: base64Decode(json['data']),
      position: Offset(
          json['position']['x'].toDouble(), json['position']['y'].toDouble()),
      size: Size(
          json['size']['width'].toDouble(), json['size']['height'].toDouble()),
    );
  }
}

class AnnotationElement implements CanvasElement {
  final int pdfPage;
  final List<Stroke> strokes;

  AnnotationElement({required this.pdfPage, required this.strokes});

  @override
  Map<String, dynamic> toJson() => {
        'type': 'annotation',
        'pdfPage': pdfPage,
        'strokes': strokes.map((s) => s.toJson()).toList(),
      };

  static AnnotationElement fromJson(Map<String, dynamic> json) {
    return AnnotationElement(
      pdfPage: json['pdfPage'],
      strokes:
          (json['strokes'] as List).map((s) => Stroke.fromJson(s)).toList(),
    );
  }
}
