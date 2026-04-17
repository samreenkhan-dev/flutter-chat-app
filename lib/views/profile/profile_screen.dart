// ignore_for_file: use_build_context_synchronously
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/user_avatar.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final TextEditingController _usernameController = TextEditingController();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    final userData = ref.read(authProvider).userData;
    _usernameController.text = userData?['username'] ?? "";
  }

  Future<void> _updateProfilePic() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (pickedFile != null) {
      setState(() => _isUpdating = true);
      try {
        // 1. Storage mein upload karna (Ye aapka kaam kar raha hai)
        final url = await ref.read(storageProvider.notifier).uploadFile(
          file: File(pickedFile.path),
          folder: 'avatars',
          isProfilePic: true,
        );

        if (url != null) {
          // --- CRITICAL FIX START ---
          // 2. Database (profiles table) mein URL save karna
          final userId = ref.read(authProvider).user?.id;
          if (userId != null) {
            await ref.read(authProvider.notifier).supabase
                .from('profiles')
                .update({'avatar_url': url}) // 'avatar_url' column ka naam confirm karein
                .eq('id', userId);

            debugPrint("✅ Database updated with URL: $url");
          }
          // --- CRITICAL FIX END ---

          // 3. Local state refresh karna
          await ref.read(authProvider.notifier).fetchCurrentUserData();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Photo Updated!")));
          }
        }
      } catch (e) {
        debugPrint("🚨 Error in Update: $e");
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    }
  }
  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final userData = authState.userData;

    // Cache busting timestamp
    final String currentAvatar = userData?['avatar_url'] != null
        ? "${userData?['avatar_url']}?t=${DateTime.now().millisecondsSinceEpoch}"
        : "";

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text("My Profile"), backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Center(
              child: Stack(
                children: [
                  UserAvatar(url: currentAvatar, username: userData?['username'] ?? "U", radius: 65),
                  Positioned(
                    bottom: 0, right: 0,
                    child: GestureDetector(
                      onTap: _isUpdating ? null : _updateProfilePic,
                      child: const CircleAvatar(backgroundColor: AppColors.accent, radius: 20, child: Icon(Icons.camera_alt, color: Colors.white, size: 20)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _buildField("Username", _usernameController),
            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity, height: 55,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () async {
                  setState(() => _isUpdating = true);
                  await ref.read(authProvider.notifier).supabase.from('profiles').update({'username': _usernameController.text.trim()}).eq('id', authState.user!.id);
                  await ref.read(authProvider.notifier).fetchCurrentUserData();
                  setState(() => _isUpdating = false);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Saved!")));
                },
                child: _isUpdating ? const CircularProgressIndicator(color: Colors.white) : const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(labelText: label, labelStyle: const TextStyle(color: Colors.white38), filled: true, fillColor: AppColors.shadowDark, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
    );
  }
}