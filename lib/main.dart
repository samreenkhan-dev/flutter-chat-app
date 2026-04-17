// ... baqi imports wahi rahengi
import 'package:chatapp/providers/auth_provider.dart';
import 'package:chatapp/views/auth/login_screen.dart';
import 'package:chatapp/views/auth/signup_screen.dart';
import 'package:chatapp/views/chat/chat_list_screen.dart';
import 'package:chatapp/views/profile/profile_screen.dart';
import 'package:chatapp/views/splash/splash_screen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Isay lazmi import karein


// ... aapke saare imports ...

// 1. Yeh hai wo main function jo missing tha
Future<void> main() async {
  // Flutter engine initialization
  WidgetsFlutterBinding.ensureInitialized();

  // Supabase aur Dotenv initialization
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
    realtimeClientOptions: const RealtimeClientOptions(
      eventsPerSecond: 2,
      timeout: Duration(seconds: 60),
    ),
  );

  runApp(
    // Riverpod ke liye ProviderScope lazmi hai
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

// 2. Phir aapki MyApp class shuru hogi
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NutriLens Chat',
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF1E2025),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      // ✅ Phele Splash Screen dikhayen
      home: const SplashScreen(),
      routes: {
        '/login': (context) => LoginScreen(),
        '/signup': (context) => const SignupScreen(),
        '/home': (context) => const ChatListScreen(),
        '/profile': (context) => const ProfileScreen(),
      },
    );
  }
}

