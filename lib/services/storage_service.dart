import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';

/// StorageService wraps Firebase Storage operations for user-generated
/// files. Currently scoped to avatar uploads — keeping it small means
/// the security-rule path naming and lifecycle stay easy to reason about.
///
/// Path convention (matches storage.rules):
///   avatars/{userId}/avatar.jpg
///
/// Why a fixed filename per user instead of a UUID:
///   - Uploads overwrite the previous avatar (no orphaned files left behind)
///   - The download URL is bound to a specific generation token by Firebase,
///     so we still have to refresh the URL in Firestore on every upload
///   - We never need to query "which avatars does this user have?" — there's
///     always exactly one
class StorageService {
  final FirebaseStorage _storage = FirebaseStorage.instance;

  /// Upload [file] as the user's avatar. Returns the public download URL.
  /// The caller is responsible for persisting the URL to Firestore — this
  /// service deliberately doesn't touch Firestore so the layer boundary
  /// stays clean.
  Future<String> uploadAvatar({
    required String userId,
    required File file,
  }) async {
    final ref = _storage.ref('avatars/$userId/avatar.jpg');

    // SettableMetadata declares contentType so Firebase serves the file
    // with the correct MIME type and our security rule's content-type
    // check passes.
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );

    return task.ref.getDownloadURL();
  }

  /// Delete the user's avatar. No-op if no avatar exists yet (Storage
  /// throws object-not-found which we swallow — the caller's intent is
  /// "make sure there's no avatar," not "an avatar definitely existed").
  Future<void> deleteAvatar(String userId) async {
    try {
      await _storage.ref('avatars/$userId/avatar.jpg').delete();
    } on FirebaseException catch (e) {
      if (e.code == 'object-not-found') return;
      rethrow;
    }
  }
}