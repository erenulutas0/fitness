import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:forma_rules/forma_rules.dart';

import 'forma_pose_platform_interface.dart';
import 'frame_codec.dart';

/// Default implementation backed by the native engines.
class MethodChannelFormaPose extends FormaPosePlatform {
  MethodChannelFormaPose({
    @visibleForTesting MethodChannel? methodChannel,
    @visibleForTesting EventChannel? eventChannel,
  }) : _methods = methodChannel ?? const MethodChannel('forma_pose/methods'),
       _events = eventChannel ?? const EventChannel('forma_pose/frames');

  final MethodChannel _methods;
  final EventChannel _events;
  Stream<PoseFrame>? _frames;
  bool _running = false;

  @override
  bool get isRunning => _running;

  @override
  bool get supportsPreview =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  Future<PoseEngineInfo> start([
    PoseStartOptions options = const PoseStartOptions(),
  ]) async {
    try {
      final raw = await _methods.invokeMapMethod<String, Object?>(
        'start',
        options.toMap(),
      );
      _running = true;
      final m = raw ?? const <String, Object?>{};
      return PoseEngineInfo(
        engine: m['engine'] as String? ?? 'mediapipe',
        model: PoseModel.values.firstWhere(
          (v) => v.name == m['model'],
          orElse: () => options.model,
        ),
        gpu: m['gpu'] as bool? ?? options.gpu,
        width: (m['width'] as num?)?.toInt() ?? options.targetWidth,
        height: (m['height'] as num?)?.toInt() ?? options.targetHeight,
        lens: options.lens,
      );
    } on PlatformException catch (e) {
      throw PoseEngineException(
        PoseErrorCode.parse(e.code),
        e.message ?? e.code,
      );
    } on MissingPluginException {
      throw const PoseEngineException(
        PoseErrorCode.notSupported,
        'forma_pose is not available on this platform',
      );
    }
  }

  @override
  Future<void> stop() async {
    _running = false;
    try {
      await _methods.invokeMethod<void>('stop');
    } on MissingPluginException {
      // nothing to stop
    }
  }

  @override
  Stream<PoseFrame> get frames => _frames ??= _events
      .receiveBroadcastStream()
      .map((dynamic event) {
        if (event is ByteData) return PoseFrameCodec.decode(event);
        if (event is Uint8List) {
          return PoseFrameCodec.decode(ByteData.sublistView(event));
        }
        throw FormatException('unexpected pose event ${event.runtimeType}');
      })
      .transform(
        StreamTransformer<PoseFrame, PoseFrame>.fromHandlers(
          handleError: (e, st, sink) {
            if (e is PlatformException) {
              sink.addError(
                PoseEngineException(
                  PoseErrorCode.parse(e.code),
                  e.message ?? e.code,
                ),
                st,
              );
            } else {
              sink.addError(e, st);
            }
          },
        ),
      );

  @override
  Future<void> setModel(PoseModel model) async {
    try {
      await _methods.invokeMethod<void>('setModel', {'model': model.name});
    } on PlatformException catch (e) {
      throw PoseEngineException(
        PoseErrorCode.parse(e.code),
        e.message ?? e.code,
      );
    }
  }

  @override
  Future<bool> hasCameraPermission() async {
    try {
      return await _methods.invokeMethod<bool>('hasCameraPermission') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> requestCameraPermission() async {
    try {
      return await _methods.invokeMethod<bool>('requestCameraPermission') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }
}
