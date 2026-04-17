import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/neumorphic_input.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passController = TextEditingController();

  LoginScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      // Ye keyboard khulne par content ko push karega lekin scroll allow karega
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            // Bouncing effect se design premium lagta hai
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),

                // --- Premium Logo Area ---
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(25),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.5),
                        offset: const Offset(10, 10),
                        blurRadius: 20,
                      ),
                      BoxShadow(
                        color: Colors.white.withOpacity(0.05),
                        offset: const Offset(-10, -10),
                        blurRadius: 20,
                      ),
                    ],
                  ),
                  child: const Icon(
                      Icons.lock_person_rounded,
                      color: AppColors.accent,
                      size: 50
                  ),
                ),

                const SizedBox(height: 40),
                const Text(
                    "Welcome Back",
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2
                    )
                ),
                const SizedBox(height: 8),
                const Text(
                    "Login to your account",
                    style: TextStyle(color: Colors.white38, fontSize: 16)
                ),

                const SizedBox(height: 50),

                // --- Inputs ---
                NeumorphicInput(hint: "Email", icon: Icons.email_outlined, controller: emailController),
                const SizedBox(height: 25),
                NeumorphicInput(hint: "Password", icon: Icons.lock_outline, controller: passController, isPassword: true),

                const SizedBox(height: 15),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {},
                    child: const Text("Forgot Password?", style: TextStyle(color: Colors.white24)),
                  ),
                ),

                const SizedBox(height: 30),

                // --- Login Button with Animated Touch ---
                GestureDetector(
                  onTap: authState.isLoading ? null : () async {
                    try {
                      await ref.read(authProvider.notifier).login(
                          emailController.text.trim(),
                          passController.text.trim()
                      );

                      if (context.mounted) {
                        Navigator.pushReplacementNamed(context, '/home');
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(e.toString()),
                              backgroundColor: Colors.redAccent,
                              behavior: SnackBarBehavior.floating,
                            )
                        );
                      }
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: LinearGradient(
                        colors: authState.isLoading
                            ? [Colors.grey, Colors.grey]
                            : [AppColors.accent, AppColors.accent.withOpacity(0.8)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        )
                      ],
                    ),
                    child: Center(
                      child: authState.isLoading
                          ? const SizedBox(
                        height: 25,
                        width: 25,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                          : const Text(
                          "LOGIN",
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                              fontSize: 16
                          )
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // --- Sign Up Link ---
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/signup'),
                  child: RichText(
                    text: const TextSpan(
                        text: "Don't have an account? ",
                        style: TextStyle(color: Colors.white38),
                        children: [
                          TextSpan(
                              text: "Sign Up",
                              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold)
                          ),
                        ]
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}