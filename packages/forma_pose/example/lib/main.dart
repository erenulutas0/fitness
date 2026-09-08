import 'dart:async';

import 'package:flutter/material.dart';
import 'package:forma_pose/forma_pose.dart';
import 'package:forma_rules/forma_rules.dart';

/// Minimal engine demo: camera preview + landmark dots + fps / inference
/// overlay (docs/10 Prompt 2). Falls back to the fake engine where the native
/// engine is unavailable.
void main() => runApp(const MaterialApp(home: EngineDemo()));

class EngineDemo extends StatefulWidget {
  const EngineDemo({super.key});

  @override
  State<EngineDemo> createState() => _EngineDemoState();
}

class _EngineDemoState extends State<EngineDemo> {
  PoseFrame? _frame;
  PoseEngineInfo? _info;
  String? _error;
  StreamSubscription<PoseFrame>? _sub;
  PoseModel _model = PoseModel.lite;

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    try {
      if (!await FormaPose.hasCameraPermission()) {
        await FormaPose.requestCameraPermission();
      }
      final info = await FormaPose.start(PoseStartOptions(model: _model));
      setState(() => _info = info);
    } on PoseEngineException catch (e) {
      if (e.code == PoseErrorCode.notSupported) {
        FormaPose.engine = FakeFormaPose.syntheticSquat(valgus: 0.3);
        final info = await FormaPose.start();
        setState(() {
          _info = info;
          _error = 'native engine unavailable → fake';
        });
      } else {
        setState(() => _error = e.toString());
        return;
      }
    }
    _sub = FormaPose.frames.listen((f) => setState(() => _frame = f));
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    unawaited(FormaPose.stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final f = _frame;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const PosePreview(),
          if (f != null) CustomPaint(painter: _DotsPainter(f)),
          Positioned(
            left: 12,
            right: 12,
            top: 40,
            child: DefaultTextStyle(
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontFamily: 'monospace',
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_info?.toString() ?? 'starting…'),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.orange)),
                  if (f != null) ...[
                    Text('fps ${f.fps?.toStringAsFixed(1) ?? '-'}'),
                    Text(
                      'inference ${f.inferenceMs?.toStringAsFixed(1) ?? '-'} ms',
                    ),
                    Text(
                      'pose ${f.hasPose}  vis ${f.meanVisibility(coreLandmarks).toStringAsFixed(2)}',
                    ),
                    Text(
                      'frame ${f.width}x${f.height}  light ${f.brightness?.toStringAsFixed(2) ?? '-'}',
                    ),
                  ],
                ],
              ),
            ),
          ),
          Positioned(
            right: 12,
            bottom: 24,
            child: FilledButton(
              onPressed: () async {
                _model = _model == PoseModel.lite
                    ? PoseModel.full
                    : PoseModel.lite;
                try {
                  await FormaPose.setModel(_model);
                } on PoseEngineException catch (e) {
                  setState(() => _error = e.toString());
                }
                setState(() {});
              },
              child: Text('model: ${_model.name}'),
            ),
          ),
        ],
      ),
    );
  }
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.frame);

  final PoseFrame frame;

  @override
  void paint(Canvas canvas, Size size) {
    if (!frame.hasPose) return;
    // The preview cover-fits the camera image, so the overlay has to use the
    // same mapping or the skeleton drifts away from the body.
    final aspect = frame.aspect;
    final boxAspect = size.width / size.height;
    final drawH = aspect > boxAspect ? size.height : size.width / aspect;
    final drawW = aspect > boxAspect ? size.height * aspect : size.width;
    final dx = (size.width - drawW) / 2;
    final dy = (size.height - drawH) / 2;
    final line = Paint()
      ..color = const Color(0xFFC8FF3D)
      ..strokeWidth = 2;
    final dot = Paint()..color = const Color(0xFF5AD8FF);
    Offset p(PoseLandmark l) =>
        Offset(dx + frame[l].x * drawW, dy + frame[l].y * drawH);
    for (final (a, b) in skeletonEdges) {
      if (frame[a].visibility < 0.5 || frame[b].visibility < 0.5) continue;
      canvas.drawLine(p(a), p(b), line);
    }
    for (final l in PoseLandmark.values) {
      if (frame[l].visibility < 0.5) continue;
      canvas.drawCircle(p(l), 4, dot);
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.frame != frame;
}
