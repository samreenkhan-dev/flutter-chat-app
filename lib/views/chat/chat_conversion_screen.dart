// ignore_for_file: use_build_context_synchronously, deprecated_member_use
import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:photo_view/photo_view.dart';

import '../../core/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/storage_provider.dart';
import '../../widgets/user_avatar.dart';

import 'package:audioplayers/audioplayers.dart' as ap;

class ChatConversationScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> receiver;
  const ChatConversationScreen({super.key, required this.receiver});

  @override
  ConsumerState<ChatConversationScreen> createState() => _ChatConversationScreenState();
}

class _ChatConversationScreenState extends ConsumerState<ChatConversationScreen> with WidgetsBindingObserver{
  final TextEditingController _msgController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late RecorderController _recorderController;
  late final StreamSubscription _messageSub;

  bool _isRecording = false;
  bool _isUploading = false;
  bool _showSendButton = false;
  Map<String, dynamic>? _replyMessage;

  static const Color accentColor = Color(0xFFC2185B);
  static const Color senderBubble = Color(0xFFC2185B);
  static const Color receiverBubble = Color(0xFF2A2D35);
  static const Color bgDark = Color(0xFF1E2025);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _recorderController = RecorderController()
      ..androidEncoder = AndroidEncoder.aac
      ..androidOutputFormat = AndroidOutputFormat.mpeg4
      ..sampleRate = 44100;

    _msgController.addListener(() {
      if (mounted) setState(() => _showSendButton = _msgController.text.trim().isNotEmpty);
    });

    Future.microtask(() => ref.read(chatServiceProvider).markAsRead(widget.receiver['id']));


  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _msgController.dispose();
    _recorderController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      ref.read(authProvider.notifier).updateUserStatus("Offline");
    } else if (state == AppLifecycleState.resumed) {
      ref.read(authProvider.notifier).updateUserStatus("Online");
    }
  }

  String _formatLastSeen(dynamic timestamp) {
    if (timestamp == null) return "Offline";
    try {
      final DateTime date = DateTime.parse(timestamp.toString()).toLocal();
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return "Just now";
      if (diff.inMinutes < 60) return "${diff.inMinutes}m ago";
      if (diff.inHours < 24 && now.day == date.day) {
        return DateFormat('hh:mm a').format(date);
      }
      return DateFormat('dd/MM/yy').format(date);
    } catch (e) {
      return "Offline";
    }
  }

  // --- CORE MEDIA HANDLING ---
  Future<void> _handleMedia(String type, [File? file]) async {
    File? selected = file;

    if (type != 'voice' && file == null) {
      final picker = ImagePicker();
      final picked = type == 'image'
          ? await picker.pickImage(source: ImageSource.gallery, imageQuality: 50)
          : await picker.pickVideo(source: ImageSource.gallery);
      if (picked == null) return;
      selected = File(picked.path);
    }

    if (mounted) setState(() => _isUploading = true);

    try {
      final url = await ref.read(storageProvider.notifier).uploadFile(
        file: selected!,
        folder: type == 'image' ? 'images' : (type == 'video' ? 'videos' : 'voice'),
        isProfilePic: false,
      );

      if (url != null) {
        await ref.read(chatServiceProvider).sendMessage(
          receiverId: widget.receiver['id'],
          content: type == 'image' ? "📷 Photo" : (type == 'voice' ? "🎤 Voice Note" : "🎥 Video"),
          type: type,
          fileUrl: url,
          replyTo: _replyMessage,
        );

        if (mounted) {
          setState(() {
            _replyMessage = null;
            _isUploading = false;
          });
          _scrollController.animateTo(0, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: receiverBubble,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (c) => Container(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _pItem(Icons.camera_alt, "Camera", () async {
              final picked = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 50);
              if (picked != null) _handleMedia('image', File(picked.path));
            }, Colors.pink),
            _pItem(Icons.image, "Gallery", () => _handleMedia('image'), Colors.blue),
            _pItem(Icons.videocam, "Video", () => _handleMedia('video'), Colors.orange),
          ],
        ),
      ),
    );
  }

  Widget _pItem(IconData i, String l, VoidCallback t, Color c) {
    return InkWell(
      onTap: () { Navigator.pop(context); t(); },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(backgroundColor: c.withOpacity(0.1), child: Icon(i, color: c)),
          const SizedBox(height: 8),
          Text(l, style: const TextStyle(color: Colors.white70)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesStreamProvider(widget.receiver['id']));
    final myId = ref.read(authProvider).user?.id;
    // ✅ statusAsync yahan define kiya gaya hai
    final statusAsync = ref.watch(userStatusProvider(widget.receiver['id']));

    return Scaffold(
      backgroundColor: bgDark,
      appBar: _buildAppBar(statusAsync), // ✅ statusAsync pass kiya
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: accentColor)),
              error: (e, _) => const Center(child: Text("Connection Lost", style: TextStyle(color: Colors.white38))),
              // Purana: data: (msgs) { ... }
// Naya (Replace with this):
              data: (msgs) {
                if (msgs.isEmpty) return const Center(child: Text("No messages yet.", style: TextStyle(color: Colors.white24)));

                // ✅ YE LOGIC ADD KAREIN (Single Tick to Double Tick Fix)
                final lastMessage = msgs.first;
                final myId = ref.read(authProvider).user?.id;
                if (lastMessage['receiver_id'] == myId && lastMessage['is_seen'] == true) {
                  // Agar main receiver hoon aur message unread hai, toh foran database update karo
                  Future.microtask(() => ref.read(chatServiceProvider).markAsRead(widget.receiver['id']));
                }

                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  itemCount: msgs.length,
                  itemBuilder: (context, i) {
                    final m = msgs[i];
                    return SwipeTo(
                      onRightSwipe: (details) => setState(() => _replyMessage = m),
                      child: GestureDetector(
                        onLongPress: () => _showDeleteDialog(m, myId),
                        child: _buildBubble(m, myId),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          if (_replyMessage != null) _buildReplyPreviewArea(),
          if (_isUploading) const LinearProgressIndicator(color: accentColor, minHeight: 2),
          _buildInputArea(),
        ],
      ),
    );
  }

  // --- UI IMPROVEMENTS ---

  Widget _buildBubble(Map<String, dynamic> msg, String? myId) {
    final bool isMe = msg['sender_id'] == myId;
    final bool isSeen = msg['is_seen'] ?? false;

    // ✅ FIX: Image aur Video dono ko handle karne ke liye
    final String messageType = msg['message_type'] ?? 'text';
    final bool isMedia = messageType == 'video' || messageType == 'image';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Flexible(
                  child: Container(
                    // ✅ Media (Image/Video) ke liye padding 0 taake black border fit aaye
                    padding: isMedia ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      // ✅ Media ke liye hamesha Transparent taake pink background na dikhe
                      color: isMedia ? Colors.transparent : (isMe ? senderBubble : receiverBubble),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMediaContent(msg, isMe),

                        // Timestamp area
                        Padding(
                          padding: isMedia
                              ? const EdgeInsets.only(top: 4, left: 2, bottom: 2)
                              : EdgeInsets.zero,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                msg['created_at'] != null
                                    ? DateFormat('hh:mm a').format(DateTime.parse(msg['created_at'].toString()).toLocal())
                                    : "",
                                style: const TextStyle(color: Colors.white38, fontSize: 10),
                              ),
                              if (isMe) ...[
                                const SizedBox(width: 4),
                                Icon(
                                  isSeen ? Icons.done_all : Icons.done,
                                  size: 14,
                                  color: isSeen ? Colors.blueAccent : Colors.white38,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
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

  // ✅ Fixed AppBar with Thin White Line and Correct Scope
  PreferredSizeWidget _buildAppBar(AsyncValue<Map<String, dynamic>?> statusAsync) {
    return AppBar(
      backgroundColor: bgDark,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: statusAsync.when(
        data: (profile) {
          final status = profile?['status'] ?? "Offline";
          final isOnline = status == "Online";
          final lastSeen = profile?['last_seen'];

          return Row(
            children: [
              Stack(
                children: [
                  UserAvatar(url: profile?['avatar_url'], username: profile?['username'] ?? "U", radius: 20),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: isOnline ? Colors.green : Colors.transparent,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 0.5), // ✅ Thin White Line
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile?['username'] ?? widget.receiver['username'],
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  Text(
                    isOnline ? "Online" : "Last seen: ${_formatLastSeen(lastSeen)}",
                    style: TextStyle(fontSize: 11, color: isOnline ? Colors.green : Colors.white38),
                  ),
                ],
              ),
            ],
          );
        },
        loading: () => Text(widget.receiver['username'], style: const TextStyle(color: Colors.white)),
        error: (e, _) => Text(widget.receiver['username'], style: const TextStyle(color: Colors.white)),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.videocam_outlined, color: Colors.white70), onPressed: () {}),
        IconButton(icon: const Icon(Icons.call_outlined, color: Colors.white70), onPressed: () {}),
      ],
    );
  }

  Widget _buildMediaContent(Map<String, dynamic> msg, bool isMe) {
    final url = msg['file_url'];
    const double fixedHeight = 240.0; // 240 logical pixels height

    switch (msg['message_type']) {
    // Purana case 'image': return Container(...)
// Naya (Replace with this):
      case 'image':
        return GestureDetector(
          onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => FullImageScreen(url: url ?? ""))
          ),
          child: Container(
            height: fixedHeight,
            width: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.black.withOpacity(0.8), width: 0.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14.5),
              child: Image.network(
                url ?? "",
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, color: Colors.white24),
              ),
            ),
          ),
        );
      case 'video':
        return Container(
          height: fixedHeight,
          width: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.black.withOpacity(0.8), width: 0.5),
          ),
          child: VideoBubbleWidget(url: url ?? ""),
        );

      case 'voice':
      // ✅ Voice note ka width control kiya taake bubble chota rahay
        return SizedBox(
            width: 180,
            child: VoiceWaveformPlayer(url: url ?? "", isMe: isMe)
        );

      default:
        return Text(msg['content'] ?? "", style: const TextStyle(color: Colors.white, fontSize: 15));
    }
  }



  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 30),
      color: bgDark,
      child: Row(
        children: [
          IconButton(icon: const Icon(Icons.add_circle_outline, color: accentColor, size: 32), onPressed: _showPicker),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(color: const Color(0xFF121316), borderRadius: BorderRadius.circular(25)),
              child: _isRecording
                  ? AudioWaveforms(size: const Size(150, 45), recorderController: _recorderController, waveStyle: const WaveStyle(waveColor: accentColor))
                  : TextField(
                controller: _msgController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(hintText: "Message...", border: InputBorder.none, hintStyle: TextStyle(color: Colors.white24)),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onLongPress: () async {
              if (!_showSendButton) {
                await _recorderController.record();
                setState(() => _isRecording = true);
              }
            },
            onLongPressUp: () async {
              if (_isRecording) {
                final path = await _recorderController.stop();
                setState(() => _isRecording = false);
                if (path != null) await _handleMedia('voice', File(path));
              }
            },
            // InputArea ke onTap mein change karein:
            onTap: () async {
              if (_showSendButton) {
                final content = _msgController.text.trim();
                _msgController.clear();

                await ref.read(chatServiceProvider).sendMessage(
                  receiverId: widget.receiver['id'],
                  content: content,
                  replyTo: _replyMessage,
                );

                // ✅ FIX: UI ko foran refresh karne ke liye
                ref.invalidate(messagesStreamProvider(widget.receiver['id']));

                setState(() => _replyMessage = null);
              }
            },
            child: CircleAvatar(
              backgroundColor: accentColor,
              child: Icon(_showSendButton ? Icons.send : Icons.mic, color: Colors.white, size: 22),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(Map<String, dynamic> msg, String? myId) {
    if (msg['sender_id'] != myId) return;

    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: const Color(0xFF2A2D35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Text("Delete Message", style: TextStyle(color: Colors.white)),
        content: const Text(
          "Are you sure you want to delete this message?",
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text("Cancel", style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(c); // Dialog band karein

              try {
                // 1. Database se delete karein
                await ref.read(chatServiceProvider).deleteMessage(
                    msg['id'].toString(),
                    fileUrl: msg['file_url'],
                    type: msg['message_type']
                );

                // ✅ 2. FIX: UI ko foran refresh karne ke liye ye line add karein
                // Isse deleted message screen se foran gayab ho jayega
                ref.invalidate(messagesStreamProvider(widget.receiver['id']));

                // Optional: Success message
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Message deleted"), duration: Duration(seconds: 1)),
                  );
                }
              } catch (e) {
                debugPrint("🚨 Delete Error: $e");
              }
            },
            child: const Text("Delete", style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInsideReplyBubble(Map<String, dynamic> reply) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(10), border: const Border(left: BorderSide(color: Colors.white70, width: 3))),
      child: Text(reply['content'] ?? "Media", maxLines: 2, style: const TextStyle(color: Colors.white60, fontSize: 12)),
    );
  }

  Widget _buildReplyPreviewArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: const BoxDecoration(color: receiverBubble),
      child: Row(
        children: [
          const Icon(Icons.reply, color: accentColor),
          const SizedBox(width: 10),
          Expanded(child: Text(_replyMessage!['content'], style: const TextStyle(color: Colors.white70), maxLines: 1)),
          IconButton(icon: const Icon(Icons.close, color: Colors.white), onPressed: () => setState(() => _replyMessage = null)),
        ],
      ),
    );
  }
}



class VoiceWaveformPlayer extends StatefulWidget {
  final String url;
  final bool isMe;
  const VoiceWaveformPlayer({super.key, required this.url, required this.isMe});

  @override
  State<VoiceWaveformPlayer> createState() => _VoiceWaveformPlayerState();
}

class _VoiceWaveformPlayerState extends State<VoiceWaveformPlayer> {
  late PlayerController controller;
  bool isReady = false;
  bool isDownloading = true;

  @override
  void initState() {
    super.initState();
    controller = PlayerController();
    _prepareVoiceNote();

    // UI update listener
    controller.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _prepareVoiceNote() async {
    try {
      // 1. Local path create karna (Infinix/Android fix)
      final directory = await getTemporaryDirectory();
      final String fileName = widget.url.split('/').last.split('?').first;
      final String localPath = '${directory.path}/$fileName';
      final file = File(localPath);

      // 2. Agar file pehle se downloaded nahi hai toh download karein
      if (!await file.exists()) {
        final response = await http.get(Uri.parse(widget.url));
        await file.writeAsBytes(response.bodyBytes);
      }

      // 3. Local path se player prepare karna
      await controller.preparePlayer(
        path: localPath,
        shouldExtractWaveform: true,
        volume: 1.0,
      );

      if (mounted) {
        setState(() {
          isReady = true;
          isDownloading = false;
        });
      }
    } catch (e) {
      debugPrint("🚨 Voice Player Fatal Error: $e");
      if (mounted) setState(() => isDownloading = false);
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  // VoiceWaveformPlayer ke build method mein Row ko aise update karein:
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      // Bubble ki width control karne ke liye hum isay constrain karenge
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.7, // 70% max width
      ),
      decoration: BoxDecoration(
        color: widget.isMe ? Colors.black12 : Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min, // Chota bubble banayega
        children: [
          GestureDetector(
            onTap: () async {
              if (!isReady) return;
              if (controller.playerState.isPlaying) {
                await controller.pausePlayer();
              } else {
                await controller.startPlayer();
              }
              if (mounted) setState(() {});
            },
            child: Icon(
              controller.playerState.isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_filled_rounded,
              color: Colors.white,
              size: 34,
            ),
          ),
          const SizedBox(width: 4),

          // ✅ FIX: Overflow khatam karne ke liye Expanded use karein
          if (isDownloading)
            const Expanded(
              child: SizedBox(
                width: 100, // Min width placeholder
                child: LinearProgressIndicator(
                  backgroundColor: Colors.white10,
                  color: Colors.white38,
                  minHeight: 2,
                ),
              ),
            )
          else if (isReady)
            Expanded( // ✅ Available space occupy karega bina overflow ke
              child: AudioFileWaveforms(
                size: const Size(double.infinity, 35), // Width auto lega
                playerController: controller,
                waveformType: WaveformType.fitWidth,
                playerWaveStyle: PlayerWaveStyle(
                  fixedWaveColor: Colors.white24,
                  liveWaveColor: widget.isMe ? Colors.white : const Color(0xFFC2185B),
                  spacing: 4,
                  waveThickness: 2,
                ),
              ),
            )
          else
            const Text("Error", style: TextStyle(color: Colors.white38, fontSize: 10)),
        ],
      ),
    );
  }
}

// --- VIDEO & IMAGE UTILS ---
class VideoBubbleWidget extends StatefulWidget {
  final String url;
  const VideoBubbleWidget({super.key, required this.url});
  @override State<VideoBubbleWidget> createState() => _VideoBubbleWidgetState();
}
class _VideoBubbleWidgetState extends State<VideoBubbleWidget> {
  late VideoPlayerController _c;
  @override void initState() { super.initState(); _c = VideoPlayerController.networkUrl(Uri.parse(widget.url))..initialize().then((_) { if (mounted) setState(() {}); }); }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) {
    if (!_c.value.isInitialized) return const SizedBox(width: 50, height: 50, child: CircularProgressIndicator());
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FullVideoScreen(controller: _c))),
      child: ClipRRect(borderRadius: BorderRadius.circular(14), child: Stack(alignment: Alignment.center, children: [AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c)), const Icon(Icons.play_circle, color: Colors.white, size: 45)])),
    );
  }
}
class FullVideoScreen extends StatelessWidget {
  final VideoPlayerController controller;
  const FullVideoScreen({super.key, required this.controller});
  @override Widget build(BuildContext context) {
    return Scaffold(backgroundColor: Colors.black, body: Center(child: AspectRatio(aspectRatio: controller.value.aspectRatio, child: VideoPlayer(controller))), floatingActionButton: FloatingActionButton(onPressed: () => controller.value.isPlaying ? controller.pause() : controller.play(), child: Icon(controller.value.isPlaying ? Icons.pause : Icons.play_arrow)));
  }
}
class FullImageScreen extends StatelessWidget {
  final String url;
  const FullImageScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      // AppBar isliye taake user wapas ja sake
      appBar: AppBar(
        backgroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SizedBox.expand( // ✅ Poori screen cover karne ke liye
        child: PhotoView(
          imageProvider: NetworkImage(url),
          loadingBuilder: (context, event) => const Center(
            child: CircularProgressIndicator(color: Colors.pinkAccent),
          ),
          minScale: PhotoViewComputedScale.contained,
          maxScale: PhotoViewComputedScale.covered * 2,
        ),
      ),
    );
  }
}