import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forma_pose/forma_pose.dart';
import 'package:forma_rules/forma_rules.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/content/content_repository.dart';
import '../../workout/presentation/skeleton_painter.dart';
import '../application/recorder_controller.dart';

/// Live capture screen: framing feedback while recording raw landmarks.
/// Founder tool (debug only), copy intentionally Turkish and outside l10n.
class RecorderCaptureScreen extends ConsumerStatefulWidget {
  const RecorderCaptureScreen({required this.config, super.key});

  final RecordingConfig config;

  @override
  ConsumerState<RecorderCaptureScreen> createState() =>
      _RecorderCaptureScreenState();
}

class _RecorderCaptureScreenState extends ConsumerState<RecorderCaptureScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final bundle = await ref.read(contentRepositoryProvider.future);
      final def = bundle.exercise(widget.config.exerciseId);
      if (def == null || !mounted) return;
      await ref
          .read(recorderControllerProvider.notifier)
          .start(widget.config, def);
    });
  }

  Future<void> _stop() async {
    final draft = await ref.read(recorderControllerProvider.notifier).stop();
    if (!mounted) return;
    if (draft == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kayıt boş, dosya yazılmadı.')),
      );
      context.pop();
      return;
    }
    context.pushReplacement(Routes.recorderLabel, extra: draft);
  }

  @override
  Widget build(BuildContext context) {
    // The 3-minute cap finishes the take through the same path as the button,
    // so it lands on labelling instead of quietly leaving a stopped screen.
    ref.listen(
      recorderControllerProvider.select((s) => s.reachedLimit),
      (_, hit) {
        if (hit && mounted) unawaited(_stop());
      },
    );
    final state = ref.watch(recorderControllerProvider);
    final frame = state.frame;
    final framing = state.framing;
    final isHold =
        ref
            .watch(contentRepositoryProvider)
            .value
            ?.exercise(widget.config.exerciseId)
            ?.countMode ==
        CountMode.hold;

    return Scaffold(
      backgroundColor: FormaColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (state.engine == 'fake')
            const ColoredBox(color: FormaColors.surfaceRaised)
          else
            const PosePreview(),
          if (frame != null)
            CustomPaint(
              painter: SkeletonPainter(
                frame: frame,
                tracking: (framing?.confidence ?? 0) >= 0.5,
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _FramingBanner(framing: framing, frame: frame),
                  const Spacer(),
                  if (state.status == RecorderStatus.starting)
                    const Text('Kamera açılıyor…'),
                  if (state.status == RecorderStatus.error)
                    Text(
                      state.errorMessage ?? 'hata',
                      style: const TextStyle(color: FormaColors.warning),
                      textAlign: TextAlign.center,
                    ),
                  if (state.status == RecorderStatus.countdown)
                    Text(
                      '${state.countdownSeconds}',
                      style: Theme.of(context).textTheme.displayLarge?.copyWith(
                        color: FormaColors.secondary,
                      ),
                    ),
                  if (state.isRecording)
                    _RecordingReadout(state: state, isHold: isHold),
                  const Spacer(),
                  FilledButton.icon(
                    key: const Key('recorder_stop'),
                    style: FilledButton.styleFrom(
                      backgroundColor: state.isRecording
                          ? FormaColors.warning
                          : FormaColors.outline,
                      foregroundColor: FormaColors.background,
                    ),
                    onPressed: state.status == RecorderStatus.error
                        ? () => context.pop()
                        : _stop,
                    icon: const Icon(Icons.stop),
                    label: Text(
                      state.isRecording ? 'Durdur ve etiketle' : 'Vazgeç',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FramingBanner extends StatelessWidget {
  const _FramingBanner({required this.framing, required this.frame});

  final FramingResult? framing;
  final PoseFrame? frame;

  static const _messages = <FramingStatus, String>{
    FramingStatus.noPose: 'Kimse görünmüyor',
    FramingStatus.lowConfidence: 'Seni net göremiyorum',
    FramingStatus.tooClose: 'Biraz geri git',
    FramingStatus.tooFar: 'Biraz yaklaş',
    FramingStatus.moveTowardImageRight: 'Biraz sağa kay',
    FramingStatus.moveTowardImageLeft: 'Biraz sola kay',
    FramingStatus.ok: 'Kadraj tamam',
  };

  @override
  Widget build(BuildContext context) {
    final f = framing;
    final ok = f?.isReady ?? false;
    final text = f == null ? '…' : (_messages[f.status] ?? '');
    final light = (f != null && !f.brightnessOk) ? ' · ışık az' : '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: (ok ? FormaColors.success : FormaColors.warning).withValues(
          alpha: 0.18,
        ),
        borderRadius: BorderRadius.circular(FormaTheme.radius),
        border: Border.all(
          color: ok ? FormaColors.success : FormaColors.warning,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$text$light',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: ok ? FormaColors.success : FormaColors.warning,
            ),
          ),
          Text(
            'görünürlük ${(f?.confidence ?? 0).toStringAsFixed(2)} · '
            'boy ${(f?.bodyHeightFraction ?? 0).toStringAsFixed(2)} · '
            'açı ${f?.detectedView.name ?? '-'} · '
            'fps ${frame?.fps?.toStringAsFixed(0) ?? '-'}',
            style: const TextStyle(fontSize: 11, color: FormaColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _RecordingReadout extends StatelessWidget {
  const _RecordingReadout({required this.state, required this.isHold});

  final RecorderState state;
  final bool isHold;

  @override
  Widget build(BuildContext context) {
    final seconds = state.durationMs / 1000;
    const limit = RecorderController.maxDurationMs / 1000;
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.fiber_manual_record, color: FormaColors.warning),
            const SizedBox(width: 8),
            Text(
              '${seconds.toStringAsFixed(1)} s',
              style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        Text(
          '${state.frameCount} frame · sınır ${limit.toStringAsFixed(0)} s',
          style: const TextStyle(color: FormaColors.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Text(
          isHold
              ? 'motor: ${(state.engineHoldMs / 1000).toStringAsFixed(0)} s tutuş'
              : 'motor: ${state.engineReps} tekrar',
          style: const TextStyle(fontSize: 18, color: FormaColors.primary),
        ),
      ],
    );
  }
}
