/// The version shown on the profile and licence screens.
///
/// Mirrors `version:` in `apps/mobile/pubspec.yaml`. Reading it at runtime
/// needs `package_info_plus` (a native plugin, brief §0: no new native
/// dependency in this pass), so the string is kept by hand for now.
const appVersion = '0.1.0';
