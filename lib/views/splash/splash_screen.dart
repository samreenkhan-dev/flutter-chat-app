import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // 1. Smooth Animation Setup
    _controller = AnimationController(
      duration: Duration(milliseconds: 1800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeIn)),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack)),
    );

    _controller.forward();
    _redirect();
  }

  Future<void> _redirect() async {
    await Future.delayed(const Duration(seconds: 8));
    if (!mounted) return;

    final session = Supabase.instance.client.auth.currentSession;
    if (session != null) {
      Navigator.pushReplacementNamed(context, '/home');
    } else {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        // Alignment center stack ke items ko default center karta hai
        alignment: Alignment.center,
        children: [
          // Background Glow Effect
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Positioned(
                top: -50,
                // Isay bhi center karne ke liye width specify karni hogi
                child: Container(
                  width: 250,
                  height: 250,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.accent.withOpacity(0.05 * _controller.value),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accent.withOpacity(0.1 * _controller.value),
                        blurRadius: 100,
                        spreadRadius: 50,
                      )
                    ],
                  ),
                ),
              );
            },
          ),

          // --- MAIN CONTENT CENTERED ---
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Neumorphic Animated Logo
                ScaleTransition(
                  scale: _scaleAnimation,
                  child: FadeTransition(
                    opacity: _fadeAnimation,
                    child: Container(
                      width: 130,
                      height: 130,
                      decoration: Neumorphic.box(radius: 35),
                      child: Center(
                        child: Icon(
                          Icons.forum_rounded,
                          color: AppColors.accent,
                          size: 60,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // App Title Area
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        "CHAT APP",
                        textAlign: TextAlign.center, // Text alignment fix
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 10,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        height: 2,
                        width: 50,
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      const SizedBox(height: 15),
                      const Text(
                        "FAST . SECURE . REALTIME",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white24,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Bottom Loading (Isay bhi Positioned mein center karein)
          Positioned(
            bottom: 60,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}