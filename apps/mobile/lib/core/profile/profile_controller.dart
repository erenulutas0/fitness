import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'profile_store.dart';
import 'user_profile.dart';

part 'profile_controller.g.dart';

/// `profileProvider`: the [UserProfile], or `null` before onboarding.
///
/// Onboarding calls [save] once at the end; the profile screen calls it
/// again to edit. Disk first, then state, same as settings.
@Riverpod(keepAlive: true, name: 'profileProvider')
class ProfileController extends _$ProfileController {
  @override
  Future<UserProfile?> build() => ref.watch(profileStoreProvider).load();

  Future<void> save(UserProfile profile) async {
    await ref.read(profileStoreProvider).save(profile);
    state = AsyncData(profile);
  }

  /// "Verilerimi sil": no profile, so the router sends the user back through
  /// onboarding.
  Future<void> clear() async {
    await ref.read(profileStoreProvider).delete();
    state = const AsyncData(null);
  }
}

/// Whether onboarding has been completed. Derived from [profileProvider], so
/// it flips the moment a profile is saved or cleared.
@Riverpod(keepAlive: true)
Future<bool> hasProfile(Ref ref) async =>
    await ref.watch(profileProvider.future) != null;
