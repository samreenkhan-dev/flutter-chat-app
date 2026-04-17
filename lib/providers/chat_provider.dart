import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'supabase_provider.dart'; // Ensure correct path

class ChatService {
  final SupabaseClient _supabase;
  ChatService(this._supabase);

  // --- 1. SEND MESSAGE ---
  // --- 1. SEND MESSAGE ---
  Future<void> sendMessage({
    required String receiverId,
    required String content,
    String type = 'text',
    String? fileUrl,
    Map<String, dynamic>? replyTo,
  }) async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return;

      final ids = [myId, receiverId]..sort();
      final String roomId = ids.join('_');
      final String isoTime = DateTime.now().toUtc().toIso8601String();

      // ✅ FIX: .select() lazmi lagayein taake stream update ho
      await _supabase.from('messages').insert({
        'sender_id': myId,
        'receiver_id': receiverId,
        'room_id': roomId,
        'content': content,
        'message_type': type,
        'file_url': fileUrl,
        'reply_to': replyTo,
        'is_seen': false,
      }).select();

      // Step B: Update Inbox
      await _supabase.from('conversations').upsert({
        'id': roomId,
        'user_1': ids[0],
        'user_2': ids[1],
        'last_message': content,
        'last_message_time': isoTime,
        'sender_id': myId,


      }).select();
      await _supabase.rpc('increment_unread_count', params: {'row_id': roomId});

      debugPrint("✅ Message Sent and Stream Updated");
    } catch (e) {
      debugPrint("🚨 SEND ERROR: $e");
    }
  }

// --- 3. DELETE MESSAGE (Fix for Voice & Path) ---
  Future<void> deleteMessage(String messageId, {String? fileUrl, String? type}) async {
    try {
      final myId = _supabase.auth.currentUser?.id;
      if (myId == null) return;

      if (fileUrl != null && fileUrl.isNotEmpty) {
        // ✅ Proper way to get filename from URL
        final uri = Uri.parse(fileUrl);
        final String fileName = uri.pathSegments.last;

        // ✅ Folder name check (Voice notes aksar 'voice' folder mein hote hain)
        String folder = type == 'video' ? 'videos' : (type == 'voice' ? 'voice' : 'images');

        await _supabase.storage.from('chat_media').remove(['$folder/$fileName']);
        debugPrint("🗑️ Storage deleted: $folder/$fileName");
      }

      final response = await _supabase
          .from('messages')
          .delete()
          .eq('id', int.tryParse(messageId) ?? messageId)
          .eq('sender_id', myId)
          .select();

      if (response.isEmpty) {
        debugPrint("⚠️ DELETE FAILED: Row not found or RLS issue.");
      }
    } catch (e) {
      debugPrint("🚨 DELETE ERROR: $e");
    }
  }

  // --- 2. MARK AS READ ---
  // --- 2. MARK AS READ (Fix for Double Ticks) ---
  Future<void> markAsRead(String otherUserId) async {
    final myId = _supabase.auth.currentUser?.id;
    if (myId == null) return;

    final ids = [myId, otherUserId]..sort();
    final String roomId = ids.join('_');

    try {
      // 1. Messages table mein update (Double Tick fix ke liye)
      // Sirf wo messages 'seen' mark hon jo MUJHY bhejay gaye hain
      await _supabase
          .from('messages')
          .update({'is_seen': true})
          .eq('room_id', roomId)
          .eq('receiver_id', myId)
          .eq('is_seen', false)
          .select(); // ✅ select() realtime signal ke liye zaroori hai

      // 2. Conversations table mein unread count reset (Notification Dot fix ke liye)
      await _supabase
          .from('conversations')
          .update({'unread_count': 0})
          .eq('id', roomId)
          .select(); // ✅ Yahan bhi select() add karein taake Inbox foran update ho

      debugPrint("✅ Database: Ticks & Unread count updated successfully.");
    } catch (e) {
      debugPrint("🚨 MARK AS READ ERROR: $e");
    }
  }
// --- 3. DELETE MESSAGE (Fix for 'int' error) ---

}


final chatServiceProvider = Provider((ref) => ChatService(ref.watch(supabaseProvider)));

// ✅ MESSAGES PROVIDER (Used in ChatConversationScreen)
final messagesStreamProvider = StreamProvider.family<List<Map<String, dynamic>>, String>((ref, receiverId) {
  final supabase = ref.watch(supabaseProvider);
  final myId = supabase.auth.currentUser?.id;
  if (myId == null) return Stream.value([]);

  final ids = [myId, receiverId]..sort();
  final String roomId = ids.join('_');

  return supabase
      .from('messages')
      .stream(primaryKey: ['id'])
      .eq('room_id', roomId)
      .order('created_at', ascending: false); // Reverse List compatibility
});

// ✅ CHAT LIST (INBOX) PROVIDER
final chatListStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final myId = supabase.auth.currentUser?.id;
  if (myId == null) return Stream.value([]);

  return supabase
      .from('conversations')
      .stream(primaryKey: ['id'])
      .order('last_message_time', ascending: false)
      .asyncMap((conversations) async {

    List<Map<String, dynamic>> detailedChats = [];
    final Set<String> seenUserIds = {};

    for (var conv in conversations) {
      if (conv['user_1'] != myId && conv['user_2'] != myId) continue;

      final String otherId = conv['user_1'] == myId ? conv['user_2'] : conv['user_1'];
      if (seenUserIds.contains(otherId)) continue;

      final profile = await supabase
          .from('profiles')
          .select('username, avatar_url, status, last_seen')
          .eq('id', otherId)
          .maybeSingle();

      if (profile != null) {
        seenUserIds.add(otherId);
        detailedChats.add({
          ...conv,
          'id': otherId,
          'username': profile['username'] ?? "Unknown",
          'avatar_url': profile['avatar_url'],
          'status': profile['status'] ?? "Offline",
          'last_seen': profile['last_seen'],
        });
      }
    }
    return detailedChats;
  });
});

// ✅ USER STATUS PROVIDER (Real-time Online/Offline for AppBar)
final userStatusProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, userId) {
  final supabase = ref.watch(supabaseProvider);
  return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((data) => data.isNotEmpty ? data.first : null);
});

// ✅ ALL PROFILES (For New Chat Picker)
final allProfilesProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final myId = supabase.auth.currentUser?.id;
  return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .map((data) => data.where((u) => u['id'] != myId).toList());
});