import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_provider.dart';

class StorageNotifier extends StateNotifier<bool> {
  final SupabaseClient _supabase;
  StorageNotifier(this._supabase) : super(false);

  Future<String?> uploadFile({
    required File file,
    required String folder,
    required bool isProfilePic,
  }) async {
    state = true; // Start loading indicator
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) throw "User not authenticated";

      final myId = user.id;
      final String fileExt = file.path.split('.').last.toLowerCase();

      // UNIQUE FILENAME: Timestamp + UserID taake collision na ho
      final fileName = "${myId}_${DateTime.now().millisecondsSinceEpoch}.$fileExt";
      final path = '$folder/$fileName';

      // 1. UPLOAD TO STORAGE
      // 'contentType' set karna zaroori hai taake link open karte hi media play ho
      await _supabase.storage.from('chat_media').upload(
        path,
        file,
        fileOptions: FileOptions(
          cacheControl: '3600',
          upsert: true,
          contentType: _getMimeType(fileExt), // Auto detect type
        ),
      );

      // 2. GET PUBLIC URL
      final String publicUrl = _supabase.storage.from('chat_media').getPublicUrl(path);

      // 3. DATABASE SYNC (If Profile Pic)
      if (isProfilePic) {
        await _supabase
            .from('profiles')
            .update({'avatar_url': publicUrl})
            .eq('id', myId)
            .select();

        debugPrint("✅ Profile Picture Updated: $publicUrl");
      }

      state = false; // Stop loading
      return publicUrl;

    } catch (e) {
      state = false;
      debugPrint("🚨 Storage/DB Error: $e");
      return null;
    }
  }

  // Helper function to set content type (Zaroori for Voice/Video)
  String _getMimeType(String ext) {
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'mp4':
        return 'video/mp4';
      case 'm4a':
      case 'mp3':
        return 'audio/mpeg';
      default:
        return 'application/octet-stream';
    }
  }
}

// --- GLOBAL PROVIDER ---
final storageProvider = StateNotifierProvider<StorageNotifier, bool>((ref) {
  final client = ref.watch(supabaseProvider);
  return StorageNotifier(client);
});