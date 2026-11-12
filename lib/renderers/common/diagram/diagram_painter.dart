import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'diagram_models.dart';

final class DiagramPainter extends CustomPainter {
  const DiagramPainter({required this.scene, required this.color});

  final DiagramScene scene;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = color.withValues(alpha: 0.68)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;
    final fill = Paint()
      ..color = color.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    final label = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
      maxLines: 3,
    );
    void drawLabel(String text, Offset center, double width) {
      label.text = TextSpan(
        text: text,
        style: TextStyle(color: color, fontSize: 12, height: 1.2),
      );
      label.layout(maxWidth: width - 12);
      label.paint(canvas, center - Offset(label.width / 2, label.height / 2));
    }

    final flowchart = scene.flowchart;
    if (flowchart != null) {
      for (final edge in flowchart.edges) {
        final path = edge.path;
        if (path.length < 2) continue;
        final paint = Paint()
          ..color = line.color
          ..strokeWidth = edge.style == DiagramLineStyle.thick
              ? 3
              : line.strokeWidth
          ..style = PaintingStyle.stroke;
        if (edge.style == DiagramLineStyle.dashed) {
          for (var index = 1; index < path.length; index += 1) {
            _drawDashed(canvas, path[index - 1], path[index], paint);
          }
        } else {
          final route = Path()..moveTo(path.first.dx, path.first.dy);
          for (var index = 1; index < path.length; index += 1) {
            route.lineTo(path[index].dx, path[index].dy);
          }
          canvas.drawPath(route, paint);
        }
        if (edge.arrow == DiagramArrow.end) {
          _drawArrow(canvas, path[path.length - 2], path.last, paint);
        }
        if (edge.label.isNotEmpty) {
          final middle = path[path.length ~/ 2];
          drawLabel(edge.label, Offset(middle.dx, middle.dy - 10), 100);
        }
      }
      for (final node in flowchart.nodes) {
        final rect = node.rect;
        if (node.shape == DiagramNodeShape.diamond) {
          final path = Path()
            ..moveTo(rect.center.dx, rect.top)
            ..lineTo(rect.right, rect.center.dy)
            ..lineTo(rect.center.dx, rect.bottom)
            ..lineTo(rect.left, rect.center.dy)
            ..close();
          canvas.drawPath(path, fill);
          canvas.drawPath(path, line);
        } else {
          final radius = node.shape == DiagramNodeShape.rounded
              ? Radius.circular(18)
              : Radius.circular(4);
          final rrect = RRect.fromRectAndRadius(rect, radius);
          canvas.drawRRect(rrect, fill);
          canvas.drawRRect(rrect, line);
        }
        drawLabel(node.label, rect.center, rect.width);
      }
      return;
    }

    final sequence = scene.sequence;
    if (sequence != null) {
      for (final participant in sequence.participants) {
        final rect = Rect.fromCenter(
          center: Offset(participant.center, 24),
          width: 130,
          height: 36,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          fill,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(4)),
          line,
        );
        drawLabel(participant.label, rect.center, rect.width);
        canvas.drawLine(
          Offset(participant.center, rect.bottom),
          Offset(participant.center, scene.bounds.height - 12),
          line..style = PaintingStyle.stroke,
        );
      }
      for (final message in sequence.messages) {
        final from = sequence.participants
            .firstWhere((participant) => participant.id == message.from)
            .center;
        final to = sequence.participants
            .firstWhere((participant) => participant.id == message.to)
            .center;
        final paint = Paint()
          ..color = line.color
          ..strokeWidth = line.strokeWidth
          ..style = PaintingStyle.stroke;
        if (message.from == message.to) {
          final loop = Path()
            ..moveTo(from, message.y)
            ..lineTo(from + 38, message.y)
            ..lineTo(from + 38, message.y + 18)
            ..lineTo(from, message.y + 18);
          canvas.drawPath(loop, paint);
          _drawArrow(
            canvas,
            Offset(from + 38, message.y + 18),
            Offset(from, message.y + 18),
            paint,
          );
          drawLabel(message.label, Offset(from + 48, message.y - 12), 150);
          continue;
        }
        if (message.dashed) {
          _drawDashed(
            canvas,
            Offset(from, message.y),
            Offset(to, message.y),
            paint,
          );
        } else {
          canvas.drawLine(
            Offset(from, message.y),
            Offset(to, message.y),
            paint,
          );
        }
        _drawArrow(
          canvas,
          Offset(from, message.y),
          Offset(to, message.y),
          paint,
        );
        drawLabel(
          message.label,
          Offset((from + to) / 2, message.y - 12),
          (to - from).abs() + 80,
        );
      }
    }
  }

  void _drawDashed(Canvas canvas, Offset from, Offset to, Paint paint) {
    final distance = (to - from).distance;
    if (distance == 0) return;
    final unit = (to - from) / distance;
    const dash = 6.0;
    const gap = 4.0;
    for (var offset = 0.0; offset < distance; offset += dash + gap) {
      final end = (offset + dash).clamp(0.0, distance);
      canvas.drawLine(from + unit * offset, from + unit * end, paint);
    }
  }

  void _drawArrow(Canvas canvas, Offset from, Offset to, Paint paint) {
    final direction = (to - from).direction;
    const size = 8.0;
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - size * math.cos(direction + 0.5),
        to.dy - size * math.sin(direction + 0.5),
      )
      ..moveTo(to.dx, to.dy)
      ..lineTo(
        to.dx - size * math.cos(direction - 0.5),
        to.dy - size * math.sin(direction - 0.5),
      );
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant DiagramPainter oldDelegate) =>
      oldDelegate.scene != scene || oldDelegate.color != color;
}
