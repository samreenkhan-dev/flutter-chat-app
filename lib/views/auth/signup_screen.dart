import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/neumorphic_input.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passController = TextEditingController();

  // Email validation logic
  bool _isValidEmail(String email) {
    return RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+").hasMatch(email);
  }

  void _handleSignup() async {
    final authNotifier = ref.read(authProvider.notifier);

    // Basic Validation
    if (userController.text.isEmpty || emailController.text.isEmpty || passController.text.isEmpty) {
      _showError("Please fill all fields");
      return;
    }
    if (!_isValidEmail(emailController.text.trim())) {
      _showError("Please enter a valid email");
      return;
    }
    if (passController.text.length < 6) {
      _showError("Password must be at least 6 characters");
      return;
    }

    try {
      await authNotifier.signUp(
          emailController.text.trim(),
          passController.text.trim(),
          userController.text.trim()
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Account created successfully!"), backgroundColor: Colors.green),
        );
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      if (mounted) {
        _showError(e.toString());
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      // --- KEYBOARD FIX ---
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.background, AppColors.shadowDark.withOpacity(0.5)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            // Keyboard khulne par scroll allow karega
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              children: [
                const SizedBox(height: 60),

                // --- TOP ICON/LOGO AREA ---
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.accent.withOpacity(0.1),
                      boxShadow: [
                        BoxShadow(color: AppColors.accent.withOpacity(0.1), blurRadius: 40, spreadRadius: 10)
                      ]
                  ),
                  child: Icon(Icons.person_add_rounded,
                      size: 80, color: AppColors.accent),
                ),

                const SizedBox(height: 40),
                const Text("Create Account",
                    style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 1)),
                const SizedBox(height: 10),
                const Text("Create your profile and start chatting",
                    style: TextStyle(color: Colors.white38, fontSize: 16)),
                const SizedBox(height: 50),

                // --- INPUTS ---
                NeumorphicInput(hint: "Username", icon: Icons.person_outline, controller: userController),
                const SizedBox(height: 20),
                NeumorphicInput(hint: "Email", icon: Icons.email_outlined, controller: emailController),
                const SizedBox(height: 20),
                NeumorphicInput(hint: "Password", icon: Icons.lock_outline, controller: passController, isPassword: true),

                const SizedBox(height: 50),

                // --- SIGNUP BUTTON ---
                GestureDetector(
                  onTap: authState.isLoading ? null : _handleSignup,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: double.infinity,
                    height: 55,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(15),
                        color: AppColors.accent,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.accent.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          )
                        ]
                    ),
                    child: Center(
                      child: authState.isLoading
                          ? const SizedBox(
                          height: 25, width: 25,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                      )
                          : const Text("SIGN UP",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 16)),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // --- LOGIN LINK ---
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: RichText(
                    text: const TextSpan(
                        text: "Already have an account? ",
                        style: TextStyle(color: Colors.white38),
                        children: [
                          TextSpan(text: "Login",
                              style: TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold, fontSize: 16)),
                        ]
                    ),
                  ),
                ),
                const SizedBox(height: 50), // Bottom padding for smooth scrolling
              ],
            ),
          ),
        ),
      ),
    );
  }
}