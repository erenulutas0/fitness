import 'package:flutter_test/flutter_test.dart';
import 'package:forma_pose/forma_pose.dart';
import 'package:forma_rules/forma_rules.dart';

void main() {
  test('frame round-trips through the binary codec', () {
    final frames = const SyntheticPose().squat(view: CameraView.front, reps: 1);
    final f = PoseFrame(
      timestampMs: 123456789012,
      landmarks: frames[10].landmarks,
      worldLandmarks: frames[10].worldLandmarks,
      width: 640,
      height: 480,
      fps: 29.5,
      inferenceMs: 21.25,
      brightness: 0.42,
    );
    final bytes = PoseFrameCodec.encode(f, rotationDeg: 90);
    expect(bytes.lengthInBytes, PoseFrameCodec.frameBytesWithWorld);
    final back = PoseFrameCodec.decode(bytes);
    expect(back.timestampMs, f.timestampMs);
    expect(back.width, 640);
    expect(back.height, 480);
    expect(back.fps, closeTo(29.5, 1e-5));
    expect(back.inferenceMs, closeTo(21.25, 1e-5));
    expect(back.brightness, closeTo(0.42, 1e-5));
    for (final l in PoseLandmark.values) {
      expect(back[l].x, closeTo(f[l].x, 1e-6));
      expect(back[l].y, closeTo(f[l].y, 1e-6));
      expect(back[l].visibility, closeTo(f[l].visibility, 1e-6));
      expect(back.world(l)!.z, closeTo(f.world(l)!.z, 1e-6));
    }
  });

  test('empty frame encodes as header only', () {
    final bytes = PoseFrameCodec.encode(
      PoseFrame.empty(5, width: 640, height: 480),
    );
    expect(bytes.lengthInBytes, PoseFrameCodec.headerBytes);
    final back = PoseFrameCodec.decode(bytes);
    expect(back.hasPose, isFalse);
    expect(back.timestampMs, 5);
  });

  test('fake engine streams frames and can be swapped in', () async {
    final fake = FakeFormaPose.syntheticSquat(reps: 1, noiseStd: 0);
    FormaPose.engine = fake;
    final info = await FormaPose.start();
    expect(info.engine, 'fake');
    expect(FormaPose.isRunning, isTrue);
    final received = await FormaPose.frames.take(5).toList();
    expect(received.length, 5);
    expect(received[1].timestampMs, greaterThan(received[0].timestampMs));
    await FormaPose.stop();
    expect(FormaPose.isRunning, isFalse);
    await fake.dispose();
  });
}
