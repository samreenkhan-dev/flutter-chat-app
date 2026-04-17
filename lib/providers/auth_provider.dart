import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// 1. Auth State - Isme koi tabdeeli nahi, ye perfect hai
class AuthState {
  final bool isLoading;
  final User? user;
  final Map<String, dynamic>? userData;

  AuthState({this.isLoading = false, this.user, this.userData});

  AuthState copyWith({bool? isLoading, User? user, Map<String, dynamic>? userData}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      user: user ?? this.user,
      userData: userData ?? this.userData,
    );
  }
}

// 2. Auth Notifier (Asli Fix Yahan Hai)
class AuthNotifier extends StateNotifier<AuthState> {
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- ASLI FIX: Getter add kiya taake Profile Screen error khatam ho jaye ---
  SupabaseClient get supabase => _supabase;

  AuthNotifier() : super(AuthState(user: Supabase.instance.client.auth.currentUser)) {
    if (state.user != null) {
      fetchCurrentUserData();
    }
  }

  // Database se profile data lana
  Future<void> fetchCurrentUserData() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final data = await _supabase
          .from('profiles')
          .select()
          .eq('id', user.id)
          .single();

      state = state.copyWith(userData: data, user: user);
    } catch (e) {
      debugPrint("DEBUG: Profile Fetch Error -> $e");
    }
  }

  // LOGIN Logic
  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      // Login ke baad foran data fetch karein
      await fetchCurrentUserData();
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }
  // auth_provider.dart ke notifier mein ye change karein
  Future<void> updateUserStatus(String status) async {
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) return;

    await supabase.from('profiles').update({
      'status': status,
      'last_seen': DateTime.now().toUtc().toIso8601String(), // ✅ Last seen hamesha update hoga
    }).eq('id', userId);
  }

  // SIGNUP Logic (Improved with Default Values)
  Future<void> signUp(String email, String password, String username) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'username': username}, // Metadata mein bhi save karein
      );

      if (response.user != null) {
        // Profiles table mein entry (last_message defaults ke saath)
        await _supabase.from('profiles').upsert({
          'id': response.user!.id,
          'username': username,
          'status': 'Online',
          'last_message': 'Hey there! I am using NutriLens.',
          'last_message_time': '',
          'unread_count': 0,
        });
      }
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  // LOGOUT Logic
  Future<void> logout() async {
    try {
      await _supabase.auth.signOut();
      state = AuthState(); // Sab kuch reset
    } catch (e) {
      debugPrint("Logout Error: $e");
    }
  }
}

// 3. Global Auth Provider
final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  return AuthNotifier();
});