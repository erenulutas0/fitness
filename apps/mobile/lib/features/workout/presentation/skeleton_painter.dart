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
  });

  final PoseFrame frame;
  final bool tracking;
  final List<PoseLandmark> highlight;
  final bool mirror;

  @override
  void paint(Canvas canvas, Size size) {
    if (!frame.hasPose) return;
    final aspect = frame.aspect;
    // cover-fit the frame's aspect into the box
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
    Offset p(PoseLandmark l) {
      final lm = frame[l];
      final x = mirror ? 1 - lm.x : lm.x;
      return Offset(dx + x * drawW, dy + lm.y * drawH);
    }

    final color = tracking ? FormaColors.primary : FormaColors.textMuted;
    final line = Paint()
      ..color = color.withValues(alpha: 0.85)
      ..strokeWidth = 3
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
      canvas.drawCircle(p(l), 5, joint);
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

  @override
  bool shouldRepaint(SkeletonPainter old) =>
      old.frame != frame ||
      old.tracking != tracking ||
      old.highlight != highlight ||
      old.mirror != mirror;
}
