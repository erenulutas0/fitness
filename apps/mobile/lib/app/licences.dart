import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Puts the bundled font licences into Flutter's licence registry, so they
/// show up on the licences page next to every package licence.
///
/// This is not a nicety: the SIL Open Font License requires the licence text
/// to travel with the font. Manrope and Inter ship inside the APK, so their
/// OFL text has to ship with them and be reachable from the app — declaring
/// the .txt files as assets is what makes that true, and registering them here
/// is what makes them findable.
void registerBundledLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final font in const [
      ('Manrope', 'assets/fonts/OFL-Manrope.txt'),
      ('Inter', 'assets/fonts/OFL-Inter.txt'),
    ]) {
      try {
        final text = await rootBundle.loadString(font.$2);
        yield LicenseEntryWithLineBreaks([font.$1], text);
      } on Object catch (e) {
        // A missing licence file must not take the app down, but it is a
        // packaging mistake worth seeing in a debug run.
        debugPrint('[licences] ${font.$2}: $e');
      }
    }
  });
}
