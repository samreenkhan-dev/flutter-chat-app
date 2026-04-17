import 'package:flutter/material.dart';
import '../core/theme.dart';

class UserAvatar extends StatelessWidget {
  final String? url;
  final String username;
  final double radius;

  const UserAvatar({
    super.key,
    this.url,
    required this.username,
    this.radius = 28,
  });

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.accent.withOpacity(0.1),
      child: ClipOval(
        child: (url != null && url!.isNotEmpty)
            ? Image.network(
          url!,
          fit: BoxFit.cover,
          width: radius * 2,
          height: radius * 2,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: SizedBox(
                width: radius,
                height: radius,
                child: const CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
                ),
              ),
            );
          },
          // --- ERROR LOGIC YAHAN HAI ---
          errorBuilder: (context, error, stackTrace) {
            // Console mein technical detail print hogi
            debugPrint("xxxxxxxx AVATAR ERROR xxxxxxxx");
            debugPrint("User: $username");
            debugPrint("URL: $url");
            debugPrint("Error Detail: $error");
            debugPrint("xxxxxxxxxxxxxxxxxxxxxxxxxxxxxx");

            return _buildPlaceholder();
          },
        )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Text(
      username.isNotEmpty ? username[0].toUpperCase() : "U",
      style: TextStyle(
        color: AppColors.accent,
        fontWeight: FontWeight.bold,
        fontSize: radius * 0.8,
      ),
    );
  }
}