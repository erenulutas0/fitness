import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:forma_rules/forma_rules.dart';

import '../../../app/theme.dart';

/// Joints to flash for each rule (docs/06 §4.3: "hata eklemi kısa süre
/// turuncu yanar").
const Map<String, List<PoseLandmark>> ruleJoints = {
  'knee_valgus': [PoseLandmark.leftKnee, PoseLandmark.rightKnee],
  'front_knee_valgus': [PoseLandmark.leftKnee, PoseLandmark.rightKnee],
  'shallow_depth': [
    PoseLandmark.leftHip,
    PoseLandmark.rightHip,
    PoseLandmark.leftKnee,
    PoseLandmark.rightKnee,
  ],
  'shallow_depth_front': [PoseLandmark.leftHip, PoseLandmark.rightHip],
  'torso_lean': [PoseLandmark.leftShoulder, PoseLandmark.rightShoulder],
  'heel_rise': [PoseLandmark.leftHeel, PoseLandmark.rightHeel],
  'hip_sag': [PoseLandmark.leftHip, PoseLandmark.rightHip],
  'hip_pike': [PoseLandmark.leftHip, PoseLandmark.rightHip],
  'head_drop': [PoseLandmark.nose, PoseLandmark.leftEar, PoseLandmark.rightEar],
  'insufficient_extension': [PoseLandmark.leftHip, PoseLandmark.rightHip],
};

/// Thin skeleton overlay in normalized frame coordinates (fills its box the
/// way the preview does: cover + centre crop).
class SkeletonPainter extends CustomPainter {
  SkeletonPainter({
    required this.frame,
    required this.tracking,
    this.highlight = const [],
    this.mirror = false,
    this.fitToBody = false,
  });

  final PoseFrame frame;
  final bool tracking;
  final List<PoseLandmark> highlight;
  final bool mirror;

  /// Scale the body to fill the box instead of matching a camera preview.
  final bool fitToBody;

  @override
  void paint(Canvas canvas, Size size) {
    if (!frame.hasPose) return;
    final aspect = frame.aspect;
    final Offset Function(PoseLandmark) p;
    if (fitToBody) {
      p = _bodyFit(size, aspect);
    } else {
      // cover-fit the frame's aspect into the box, which is what the live
      // preview behind the overlay does
      final boxAspect = size.width / size.height;
      late double drawW;
      late double drawH;
      if (aspect > boxAspect) {
        drawH = size.height;
        drawW = drawH * aspect;
      } else {
        drawW = size.width;
        drawH = drawW / aspect;
      }
      final dx = (size.width - drawW) / 2;
      final dy = (size.height - drawH) / 2;
      p = (l) {
        final lm = frame[l];
        final x = mirror ? 1 - lm.x : lm.x;
        return Offset(dx + x * drawW, dy + lm.y * drawH);
      };
    }

    final color = tracking ? FormaColors.primary : FormaColors.textMuted;
    // Scale with the canvas: 3 px reads fine over a phone-sized preview and
    // like a cobweb on a 1080-wide share card.
    final stroke = math.max(3.0, size.shortestSide / 150);
    final line = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final joint = Paint()..color = color;
    for (final (a, b) in skeletonEdges) {
      if (frame[a].visibility < 0.5 || frame[b].visibility < 0.5) continue;
      canvas.drawLine(p(a), p(b), line);
    }
    for (final l in PoseLandmark.values) {
      if (l.index < PoseLandmark.leftShoulder.index && l != PoseLandmark.nose) {
        continue;
      }
      if (frame[l].visibility < 0.5) continue;
      canvas.drawCircle(p(l), stroke * 1.7, joint);
    }
    if (highlight.isNotEmpty) {
      final glow = Paint()
        ..color = FormaColors.warning.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      final core = Paint()..color = FormaColors.warning;
      for (final l in highlight) {
        if (frame[l].visibility < 0.5) continue;
        canvas
          ..drawCircle(p(l), 22, glow)
          ..drawCircle(p(l), 9, core);
      }
    }
  }

  /// Fit the body, not the camera frame.
  ///
  /// With no preview behind it there is nothing to line up with, and
  /// cover-fitting a 9:16 frame into a square leaves the person small and
  /// wherever they happened to stand. Scale the pose's own bounding box
  /// instead, keeping real proportions by working in aspect-corrected space.
  Offset Function(PoseLandmark) _bodyFit(Size size, double aspect) {
    var minX = double.infinity;
    var maxX = double.negativeInfinity;
    var minY = double.infinity;
    var maxY = double.negativeInfinity;
    for (final l in PoseLandmark.values) {
      final lm = frame[l];
      if (lm.visibility < 0.5) continue;
      final x = (mirror ? 1 - lm.x : lm.x) * aspect;
      minX = math.min(minX, x);
      maxX = math.max(maxX, x);
      minY = math.min(minY, lm.y);
      maxY = math.max(maxY, lm.y);
    }
    if (minX > maxX || minY > maxY) {
      return (l) => Offset(size.width / 2, size.height / 2);
    }
    const pad = 0.08;
    final bodyW = math.max(maxX - minX, 1e-4);
    final bodyH = math.max(maxY - minY, 1e-4);
    final scale = math.min(
      size.width * (1 - 2 * pad) / bodyW,
      size.height * (1 - 2 * pad) / bodyH,
    );
    final offsetX = (size.width - bodyW * scale) / 2 - minX * scale;
    final offsetY = (size.height - bodyH * scale) / 2 - minY * scale;
    return (l) {
      final lm = frame[l];
      final x = (mirror ? 1 - lm.x : lm.x) * aspect;
      return Offset(offsetX + x * scale, offsetY + lm.y * scale);
    };
  }

  @override
  bool shouldRepaint(SkeletonPainter old) =>
      old.frame != frame ||
      old.tracking != tracking ||
      old.highlight != highlight ||
      old.mirror != mirror ||
      old.fitToBody != fitToBody;
}
