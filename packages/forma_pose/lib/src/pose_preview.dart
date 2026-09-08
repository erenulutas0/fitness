import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'forma_pose_platform_interface.dart';

/// The native camera preview (a platform view). Frames are drawn natively;
/// nothing is copied into Flutter. Falls back to [placeholder] where the
/// engine has no preview (fake engine, desktop, web).
class PosePreview extends StatelessWidget {
  const PosePreview({super.key, this.placeholder});

  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final platform = FormaPosePlatform.instance;
    if (platform.supportsPreview && !kIsWeb) {
      final viewType = platform.previewViewType;
      switch (defaultTargetPlatform) {
        case TargetPlatform.android:
          return AndroidView(
            viewType: viewType,
            creationParamsCodec: const StandardMessageCodec(),
          );
        case TargetPlatform.iOS:
          return UiKitView(
            viewType: viewType,
            creationParamsCodec: const StandardMessageCodec(),
          );
        case TargetPlatform.fuchsia:
        case TargetPlatform.linux:
        case TargetPlatform.macOS:
        case TargetPlatform.windows:
          break;
      }
    }
    return placeholder ?? const ColoredBox(color: Color(0xFF0B0F14));
  }
}
