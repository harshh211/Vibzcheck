import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../providers/auth_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/storage_service.dart';
import 'settings_screen.dart';

/// ProfileScreen lets the user view and update their avatar, plus sign out.
/// Architecture: this screen owns the upload UX (picker + progress), but
/// the actual file upload goes through StorageService and the URL write
/// goes through FirestoreService — same layer separation as everywhere
/// else in the app.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _picker = ImagePicker();
  final _storage = StorageService();
  final _firestore = FirestoreService();

  bool _isUploading = false;

  Future<void> _pickAndUploadAvatar(String userId) async {
    // Image picker doesn't request permission itself — the OS prompts on
    // first access if needed. Image quality 75 keeps uploads small (most
    // photos compress 5x with no perceptual loss).
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 75,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked == null) return;

    setState(() => _isUploading = true);

    try {
      final url = await _storage.uploadAvatar(
        userId: userId,
        file: File(picked.path),
      );
      await _firestore.updateAvatarUrl(userId: userId, avatarUrl: url);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar updated')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar upload failed. Try again.')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _removeAvatar(String userId) async {
    setState(() => _isUploading = true);
    try {
      await _storage.deleteAvatar(userId);
      await _firestore.updateAvatarUrl(userId: userId, avatarUrl: null);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar removed')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove avatar.')),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.currentUser;

    // User just signed out — pop back immediately so AuthGate can take over.
    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: StreamBuilder<AppUser?>(
        stream: _firestore.streamUser(user.uid),
        builder: (context, snapshot) {
          final appUser = snapshot.data;
          final displayName = appUser?.displayName ?? user.displayName ?? 'You';
          final email = appUser?.email ?? user.email ?? '';
          final avatarUrl = appUser?.avatarUrl;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 16),
              _AvatarSection(
                avatarUrl: avatarUrl,
                displayName: displayName,
                isUploading: _isUploading,
                onPickAvatar: () => _pickAndUploadAvatar(user.uid),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  displayName,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
              if (email.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Center(
                    child: Text(
                      email,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ),
              const SizedBox(height: 40),

              if (avatarUrl != null && avatarUrl.isNotEmpty)
                OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Remove avatar'),
                  onPressed:
                      _isUploading ? null : () => _removeAvatar(user.uid),
                ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),

              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('Settings'),
                subtitle: const Text(
                  'Notifications and recommendation preferences',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isUploading
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        );
                      },
              ),

              const SizedBox(height: 8),

              FilledButton.tonalIcon(
                icon: auth.isSigningOut
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.logout),
                label: const Text('Sign out'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: (_isUploading || auth.isSigningOut)
                    ? null
                    : () => auth.signOut(),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Tappable circular avatar that swaps between network image, initial
/// fallback, and a progress overlay while uploading.
class _AvatarSection extends StatelessWidget {
  final String? avatarUrl;
  final String displayName;
  final bool isUploading;
  final VoidCallback onPickAvatar;

  const _AvatarSection({
    required this.avatarUrl,
    required this.displayName,
    required this.isUploading,
    required this.onPickAvatar,
  });

  @override
  Widget build(BuildContext context) {
    const size = 120.0;
    final initial = displayName.isEmpty ? '?' : displayName[0].toUpperCase();

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          GestureDetector(
            onTap: isUploading ? null : onPickAvatar,
            child: ClipOval(
              child: SizedBox(
                width: size,
                height: size,
                child: (avatarUrl != null && avatarUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: avatarUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) =>
                            _initialFallback(context, initial),
                        errorWidget: (_, __, ___) =>
                            _initialFallback(context, initial),
                      )
                    : _initialFallback(context, initial),
              ),
            ),
          ),
          if (isUploading)
            Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else
            // Camera badge in the bottom-right corner — visual cue that
            // the avatar is tappable. Only shown when not uploading so
            // the spinner can take over.
            Positioned(
              bottom: 0,
              right: 0,
              child: Material(
                color: Theme.of(context).colorScheme.primary,
                shape: const CircleBorder(),
                elevation: 2,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onPickAvatar,
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.camera_alt,
                        size: 20, color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _initialFallback(BuildContext context, String initial) {
    return Container(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Text(
        initial,
        style: Theme.of(context).textTheme.displayMedium,
      ),
    );
  }
}