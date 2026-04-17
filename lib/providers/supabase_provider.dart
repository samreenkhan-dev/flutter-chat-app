import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 1. Supabase Client
final supabaseProvider = Provider((ref) => Supabase.instance.client);

// 2. Real-time Users List Stream
final usersStreamProvider = StreamProvider<List<Map<String, dynamic>>>((ref) {
  final supabase = ref.watch(supabaseProvider);
  final myId = supabase.auth.currentUser?.id;

  return supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .order('last_message_time', ascending: false)
      .map((data) => data.where((user) => user['id'] != myId).toList());
});

// 3. Current User Data Provider
final currentUserDataProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final supabase = ref.watch(supabaseProvider);
  final myId = supabase.auth.currentUser?.id;
  if (myId == null) return null;

  final data = await supabase.from('profiles').select().eq('id', myId).single();
  return data;
});