// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../widgets/user_avatar.dart';
import 'chat_conversion_screen.dart';


class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen> with WidgetsBindingObserver {
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _forceInitialLoad();
    ref.read(authProvider.notifier).updateUserStatus("Online");
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      ref.read(authProvider.notifier).updateUserStatus("Offline");
    } else if (state == AppLifecycleState.resumed) {
      ref.read(authProvider.notifier).updateUserStatus("Online");
    }
  }

  Future<void> _forceInitialLoad() async {
    try {
      await ref.read(authProvider.notifier).fetchCurrentUserData();
      ref.invalidate(chatListStreamProvider);
    } catch (e) {
      debugPrint("🚨 Initial Load Error: $e");
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  String _formatChatTime(dynamic timestamp) {
    if (timestamp == null || timestamp.toString().isEmpty) return "";
    try {
      final DateTime date = DateTime.parse(timestamp.toString()).toLocal();
      final DateTime now = DateTime.now();
      final DateTime today = DateTime(now.year, now.month, now.day);

      if (date.isAfter(today)) {
        return DateFormat('hh:mm a').format(date);
      } else if (date.isAfter(today.subtract(const Duration(days: 1)))) {
        return "Yesterday";
      } else {
        return DateFormat('dd/MM/yy').format(date);
      }
    } catch (e) {
      return "";
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final usersAsync = ref.watch(chatListStreamProvider);
    final chatsAsync = ref.watch(chatListStreamProvider);


    // 2. Ye aapki Contacts List (Saare Users) ke liye hai
    final allProfilesAsync = ref.watch(allProfilesProvider);



    return Scaffold(
      backgroundColor: AppColors.background,
      drawer: _buildPremiumDrawer(context, authState),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            // Three horizontal lines for drawer
            icon: const Icon(Icons.notes_rounded, color: Colors.white, size: 30),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: _isSearching
            ? _buildSearchField()
            : const Text("Chat App", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.white)),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search, color: Colors.white70),
            onPressed: () => setState(() {
              _isSearching = !_isSearching;
              if (!_isSearching) { _searchQuery = ""; _searchController.clear(); }
            }),
          ),
          _buildPopupMenu(),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.accent,
        onRefresh: () async => await _forceInitialLoad(),
        child: usersAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: AppColors.accent),
          ),
          error: (err, stack) {
            // ✅ Fixed: debugPrint must be inside the block
            debugPrint("🚨 UI ERROR: $err");
            return _buildErrorState(err);
          },
          data: (allUsers) {
            final myId = ref.read(authProvider).user?.id;

            // 1. Filtering Logic
            final filtered = allUsers.where((u) {
              final isNotMe = u['id'] != myId;
              final nameMatch = (u['username'] ?? "Unknown")
                  .toString()
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase());
              return isNotMe && nameMatch;
            }).toList();

            // 2. Strong Empty State Logic
            if (filtered.isEmpty) {
              debugPrint("⚠️ INFO: Filtered list is empty. No conversations found.");

              // Agar conversations nahi hain, toh hum allProfilesProvider dikha sakte hain
              // Ya phir default empty state
              return _buildEmptyState();
            }

            debugPrint("✅ UI: Displaying ${filtered.length} active chats.");

            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final user = filtered[index];
                // ValueKey lazmi lagayein taake list properly update ho
                return _buildUserTile(user);
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.accent,
        elevation: 10,
        onPressed: () => _showContactsPicker(allProfilesAsync),
        child: const Icon(Icons.chat_bubble_rounded, color: Colors.white),
      ),
    );
  }

  Widget _buildUserTile(Map<String, dynamic> user) {
    final int unreadCount = user['unread_count'] ?? 0;
    final String lastSenderId = user['sender_id'] ?? "";
    final myId = ref.read(authProvider).user?.id;
    final bool hasNewMessage = unreadCount > 0 && lastSenderId != myId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: InkWell(
        onTap: () {
          ref.read(chatServiceProvider).markAsRead(user['id']);
          Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => ChatConversationScreen(receiver: user))
          );
        },
        child: Row(
          children: [
            // 1. Avatar with Online Glow
            Stack(
              children: [
                UserAvatar(url: user['avatar_url'], username: user['username'], radius: 30),
                if (user['status'] == "Online")
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.background, width: 2.5),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 15),

            // 2. Name and Message
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['username'] ?? "User",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: hasNewMessage ? FontWeight.bold : FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    user['last_message'] ?? "No messages yet",
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: hasNewMessage ? Colors.white70 : Colors.white38,
                      fontSize: 14,
                      fontWeight: hasNewMessage ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),

            // 3. Time and Notification Badge
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatChatTime(user['last_message_time']),
                  style: TextStyle(
                    color: hasNewMessage ? AppColors.accent : Colors.white24,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                if (hasNewMessage)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accent.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Text(
                      unreadCount > 99 ? "99+" : "$unreadCount",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- DRAWER WITH PROFILE EDIT OPTION ---
  Widget _buildPremiumDrawer(BuildContext context, AuthState auth) {
    final userData = auth.userData;
    return Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 60, 20, 30),
            width: double.infinity,
            decoration: const BoxDecoration(color: AppColors.shadowDark, borderRadius: BorderRadius.vertical(bottom: Radius.circular(30))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                UserAvatar(url: userData?['avatar_url'], username: userData?['username'] ?? "U", radius: 35),
                const SizedBox(height: 15),
                Text(userData?['username'] ?? "Welcome", style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                Text(auth.user?.email ?? "", style: const TextStyle(color: Colors.white38, fontSize: 13)),
                const SizedBox(height: 15),
                // Edit Profile Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent.withOpacity(0.2),
                    foregroundColor: AppColors.accent,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pushNamed(context, '/profile'),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text("Edit Profile"),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _drawerItem(Icons.settings_outlined, "Settings", () {}),
          _drawerItem(Icons.lock_reset_outlined, "Change Password", () {}),
          const Spacer(),
          const Divider(color: Colors.white10, indent: 20, endIndent: 20),
          // Logout wala _drawerItem change karein:
          _drawerItem(
              Icons.logout_rounded,
              "Logout",
                  () async {
                // 1. Pehle Status Offline karein
                await ref.read(authProvider.notifier).updateUserStatus("Offline");
                // 2. Phir Logout karein
                await ref.read(authProvider.notifier).logout();
                if (context.mounted) {
                  Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                }
              },
              color: Colors.redAccent
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _drawerItem(IconData icon, String title, VoidCallback onTap, {Color color = Colors.white70}) {
    return ListTile(
      leading: Icon(icon, color: color == Colors.white70 ? AppColors.accent : color),
      title: Text(title, style: TextStyle(color: color, fontSize: 16)),
      onTap: onTap,
    );
  }

  // --- REMAINDING HELPERS ---
  Widget _buildErrorState(Object err) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white24, size: 60),
          const SizedBox(height: 15),
          Text("Sync Error: $err", style: const TextStyle(color: Colors.white54)),
          ElevatedButton(onPressed: () => _forceInitialLoad(), child: const Text("Retry")),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ListView(children: [SizedBox(height: MediaQuery.of(context).size.height * 0.3), const Center(child: Text("No chats found", style: TextStyle(color: Colors.white24)))]);
  }

  Widget _buildSearchField() {
    return TextField(
      controller: _searchController,
      autofocus: true,
      style: const TextStyle(color: Colors.white),
      decoration: const InputDecoration(hintText: "Search...", border: InputBorder.none, hintStyle: TextStyle(color: Colors.white24)),
      onChanged: (val) => setState(() => _searchQuery = val),
    );
  }

  Widget _buildPopupMenu() {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, color: Colors.white70),
      color: AppColors.shadowDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      onSelected: (val) {
        if (val == 'profile') Navigator.pushNamed(context, '/profile');
        if (val == 'logout') ref.read(authProvider.notifier).logout();
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'profile', child: Text("Edit Profile")),
        const PopupMenuItem(value: 'logout', child: Text("Logout", style: TextStyle(color: Colors.redAccent))),
      ],
    );
  }

  void _showContactsPicker(AsyncValue<List<Map<String, dynamic>>> usersAsync) {

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => usersAsync.when(
        loading: () => const SizedBox(height: 200, child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Center(child: Text("Error: $e")),
        data: (users) => ListView.builder(
          shrinkWrap: true,
          itemCount: users.length,
          itemBuilder: (context, i) => ListTile(
            leading: UserAvatar(url: users[i]['avatar_url'], username: users[i]['username'] ?? "U"),
            title: Text(users[i]['username'] ?? "User", style: const TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(context, MaterialPageRoute(builder: (_) => ChatConversationScreen(receiver: users[i])));
            },
          ),
        ),
      ),
    );
  }
}