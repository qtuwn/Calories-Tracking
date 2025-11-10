import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../providers/profile_provider.dart';
import '../../models/profile.dart';

/// A circular avatar that displays the user's avatar (if set) or initials.
/// Tapping opens a simple UI to pick or enter an image path (UI-only).
class AvatarCircle extends StatelessWidget {
  final double size;

  const AvatarCircle({super.key, this.size = 96.0});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;

    Widget avatarChild;
    if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
      // Try to show as asset/network/local file. We'll try Image.network first,
      // but wrap in errorBuilder to fallback to initials.
      avatarChild = ClipOval(
        child: Image.network(
          profile.avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return _initialsCircle(profile, size);
          },
        ),
      );
    } else {
      avatarChild = _initialsCircle(profile, size);
    }

    return GestureDetector(
      onTap: () => _openPicker(context),
      child: CircleAvatar(
        radius: size / 2,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: avatarChild,
      ),
    );
  }

  Widget _initialsCircle(Profile profile, double size) {
    final initials = (profile.name.isNotEmpty)
        ? profile.name
              .trim()
              .split(' ')
              .map((s) => s.isNotEmpty ? s[0] : '')
              .take(2)
              .join()
        : 'U';
    return Center(
      child: Text(
        initials.toUpperCase(),
        style: TextStyle(fontSize: size / 3, color: Colors.white),
      ),
    );
  }

  void _openPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) {
        final TextEditingController ctrl = TextEditingController();
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Chọn ảnh đại diện',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () async {
                  // Capture provider and navigator before doing async work to avoid
                  // using BuildContext across an await.
                  final provider = context.read<ProfileProvider>();
                  final navigator = Navigator.of(context);
                  final picker = ImagePicker();
                  final XFile? picked = await picker.pickImage(
                    source: ImageSource.gallery,
                  );
                  if (picked != null) {
                    provider.uploadAvatarFromXFile(picked);
                  }
                  navigator.pop();
                },
                child: const Text('Chọn từ thư viện'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  // Capture provider and navigator before doing async work to avoid
                  // using BuildContext across an await.
                  final provider = context.read<ProfileProvider>();
                  final navigator = Navigator.of(context);
                  final picker = ImagePicker();
                  final XFile? picked = await picker.pickImage(
                    source: ImageSource.camera,
                  );
                  if (picked != null) {
                    provider.uploadAvatarFromXFile(picked);
                  }
                  navigator.pop();
                },
                child: const Text('Chụp ảnh'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'Đường dẫn ảnh (URL hoặc file)',
                ),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final path = ctrl.text.trim();
                  if (path.isNotEmpty) {
                    // In mock mode, we store local path or URL directly.
                    // If Firebase is enabled, the ProfileService will handle uploads.
                    // Here we call updateAvatarFromXFile only when a file was picked.
                    // For URLs, directly update provider.
                    context.read<ProfileProvider>().updateProfile(
                      context.read<ProfileProvider>().profile.copyWith(
                        avatarUrl: path,
                        updatedAt: DateTime.now().toUtc(),
                      ),
                    );
                  }
                  Navigator.of(context).pop();
                },
                child: const Text('Sử dụng đường dẫn'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  // Clear avatar
                  context.read<ProfileProvider>().updateProfile(
                    context.read<ProfileProvider>().profile.copyWith(
                      avatarUrl: null,
                      updatedAt: DateTime.now().toUtc(),
                    ),
                  );
                  Navigator.of(context).pop();
                },
                child: const Text('Xóa ảnh'),
              ),
            ],
          ),
        );
      },
    );
  }
}
