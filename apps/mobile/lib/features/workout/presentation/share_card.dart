import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:forma_rules/forma_rules.dart';

import '../../../app/theme.dart';
import 'skeleton_painter.dart';

/// The shareable session card (docs/06 §4.5).
///
/// A drawing, never a video: the only thing that leaves the phone is the
/// user's own joint positions, rendered as a skeleton. That is the privacy
/// promise the whole product rests on, so it is enforced by what this widget
/// can see — a [PoseFrame] and some numbers, nothing else.
class ShareCard extends StatelessWidget {
  const ShareCard({
    required this.exerciseName,
    required this.score,
    required this.statsLine,
    this.pose,
    super.key,
  });

  static const size = Size(1080, 1350);

  final String exerciseName;
  final double? score;

  /// Already-localised, e.g. "3 set · 34 tekrar". Built by the caller so the
  /// card never has to reason about plurals or units — and so it cannot say
  /// "3 × 34", which reads as 102 reps rather than 34 across three sets.
  final String statsLine;
  final PoseFrame? pose;

  @override
  Widget build(BuildContext context) {
    final scoreColor = score == null
        ? FormaColors.textMuted
        : (score! >= 85
              ? FormaColors.success
              : (score! >= 60 ? FormaColors.primary : FormaColors.warning));
    return SizedBox(
      width: size.width,
      height: size.height,
      child: ColoredBox(
        color: FormaColors.background,
        child: Padding(
          padding: const EdgeInsets.all(72),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'FORMA',
                style: TextStyle(
                  color: FormaColors.primary,
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                exerciseName,
                style: const TextStyle(
                  color: FormaColors.text,
                  fontSize: 44,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: pose == null
                    ? const SizedBox.shrink()
                    : CustomPaint(
                        size: Size.infinite,
                        painter: SkeletonPainter(
                          frame: pose!,
                          tracking: true,
                          fitToBody: true,
                        ),
                      ),
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    score == null ? '–' : score!.round().toString(),
                    style: TextStyle(
                      color: scoreColor,
                      fontSize: 180,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [ui.FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Flexible, not fixed: the stats line is localised and can
                  // grow ("3 sets · 120 seconds"), and a card that overflows
                  // is a card that ships wrong.
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Text(
                        statsLine,
                        style: const TextStyle(
                          color: FormaColors.textMuted,
                          fontSize: 40,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders [card] to PNG bytes off-screen, at [ShareCard.size].
///
/// Off-screen on purpose: the card is 1080×1350 and never appears in the UI,
/// so it does not have to fit the phone or flash on screen before sharing.
Future<Uint8List> renderShareCard(
  ShareCard card, {
  double pixelRatio = 1,
}) async {
  final boundary = RenderRepaintBoundary();
  final view = ui.PlatformDispatcher.instance.views.first;
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(ShareCard.size),
      devicePixelRatio: pixelRatio,
    ),
  );
  final pipeline = PipelineOwner()..rootNode = renderView;
  final buildOwner = BuildOwner(focusManager: FocusManager());
  renderView.prepareInitialFrame();

  final element = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: Directionality(textDirection: TextDirection.ltr, child: card),
  ).attachToRenderTree(buildOwner);
  buildOwner
    ..buildScope(element)
    ..finalizeTree();
  pipeline
    ..flushLayout()
    ..flushCompositingBits()
    ..flushPaint();

  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return data!.buffer.asUint8List();
}
