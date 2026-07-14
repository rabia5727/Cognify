// lib/screens/assistant/assistant_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/assistant_provider.dart';
import '../../models/assistant_model.dart';
import '../../services/assistant_service.dart';
import '../../constants/app_constant.dart';
import '../../widgets/common/app_header.dart';
import '../../widgets/common/robot_mascot.dart';
import 'voice_assistant_screen.dart';

class AssistantScreen extends StatefulWidget {
  final String? initialMessage;
  final String? sessionId;

  const AssistantScreen({super.key, this.initialMessage, this.sessionId});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _tts = FlutterTts();

  static const String _backendBase = 'http://localhost:8000';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<AssistantProvider>();

      if (widget.sessionId != null) {
        await provider.loadHistory(sessionId: widget.sessionId);
      } else {
        await provider.startNewChat();
      }

      provider.loadSessions();

      if (widget.initialMessage != null && mounted) {
        await provider.sendMessage(widget.initialMessage!, source: 'text');
        _scrollToBottom();
      }
    });
    _setupTts();
  }

  void _setupTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.5);
    await _tts.setVolume(1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _tts.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final provider = context.read<AssistantProvider>();
    await provider.sendMessage(text, source: 'text');
    _scrollToBottom();
  }

  Future<void> _openVoiceScreen() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const VoiceAssistantScreen()),
    );
    if (result != null && mounted) {
      final provider = context.read<AssistantProvider>();
      await provider.sendVoiceMessage(result);
      _scrollToBottom();
      final messages = provider.messages;
      if (messages.isNotEmpty && messages.last.role == 'assistant') {
        await _tts.speak(messages.last.content);
      }
    }
  }

  // ── Drawer actions — Navigator.pop closes the endDrawer ─────────────────
  Future<void> _switchSession(String sessionId) async {
    Navigator.pop(context);
    final provider = context.read<AssistantProvider>();
    await provider.switchToSession(sessionId);
    _scrollToBottom();
  }

  Future<void> _startNewChat() async {
    Navigator.pop(context);
    final provider = context.read<AssistantProvider>();
    await provider.startNewChat();
  }

  Future<void> _confirmDeleteSession(String sessionId, String title) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Chat'),
        content: Text('Delete "$title"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await context.read<AssistantProvider>().deleteSession(sessionId);
    }
  }

  // ── File helpers ─────────────────────────────────────────────────────────
  String? _extractFilename(String content) {
    final match = RegExp(r'\[FILE:([^\]]+)\]').firstMatch(content);
    return match?.group(1);
  }

  String _cleanContent(String content) {
    return content.replaceAll(RegExp(r'\[FILE:[^\]]+\]'), '').trim();
  }

  Future<void> _downloadFile(String filename) async {
    final url = Uri.parse('$_backendBase/documents/download/$filename');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open download link.')),
        );
      }
    }
  }

  // ── ✅ Robot expression logic ─────────────────────────────────────────────
  // Determines which CoCo face to show based on message content.
  // Called per-message so each bubble can show the right expression.
  RobotExpression _expressionForMessage(AssistantMessage msg) {
    final c = msg.content.toLowerCase();

    // Celebrating: task created, document ready, goal achieved
    if (c.contains('✅') ||
        c.contains('created') ||
        c.contains('your document is ready') ||
        c.contains('subtask') ||
        c.contains('well done') ||
        c.contains('great job')) {
      return RobotExpression.celebrating;
    }

    // Sad: errors, overdue, nothing found
    if (c.contains('❌') ||
        c.contains('error') ||
        c.contains('failed') ||
        c.contains('overdue') ||
        c.contains("couldn't")) {
      return RobotExpression.sad;
    }

    // Thinking: long analytical replies (study plan, breakdown)
    if (c.contains('step') ||
        c.contains('plan') ||
        c.contains('breakdown') ||
        c.contains('suggest')) {
      return RobotExpression.thinking;
    }

    return RobotExpression.happy;
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final provider = context.watch<AssistantProvider>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      // ✅ endDrawer = opens from the RIGHT side
      endDrawer: _buildSessionDrawer(theme, isDark),

      body: SafeArea(
        child: Column(
          children: [
            // ✅ AppHeader matches all other screens.
            // Back button on left, session title in center,
            // hamburger (opens right drawer) as the only action.
            Builder(
              builder: (ctx) => AppHeader(
                title: provider.currentTitle,
                onBack: () => Navigator.pop(context),
                actions: [
                  IconButton(
                    onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                    icon: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.menu_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : provider.messages.isEmpty
                      ? _buildEmptyState(theme)
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                          itemCount: provider.messages.length +
                              (provider.isTyping ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (provider.isTyping &&
                                index == provider.messages.length) {
                              return _buildTypingIndicator(theme, isDark);
                            }
                            return _buildMessageBubble(
                                provider.messages[index], theme, isDark);
                          },
                        ),
            ),
            _buildInputBar(theme, isDark, provider),
          ],
        ),
      ),
    );
  }

  // ── Right-side session drawer ────────────────────────────────────────────
  Widget _buildSessionDrawer(ThemeData theme, bool isDark) {
    return Drawer(
      backgroundColor: theme.scaffoldBackgroundColor,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Text('Your Chats',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  // ✅ + button lives inside the drawer, not in the header
                  IconButton(
                    onPressed: _startNewChat,
                    icon: Icon(Icons.add_circle_outline_rounded,
                        color: theme.colorScheme.primary),
                    tooltip: 'New Chat',
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Consumer<AssistantProvider>(
                builder: (context, provider, _) {
                  if (provider.isLoadingSessions && provider.sessions.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (provider.sessions.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'No chats yet.\nStart a conversation with CoCo!',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: provider.sessions.length,
                    itemBuilder: (context, index) {
                      final session = provider.sessions[index];
                      final isActive =
                          session.sessionId == provider.currentSessionId;
                      return _SessionTile(
                        session: session,
                        isActive: isActive,
                        onTap: () => _switchSession(session.sessionId),
                        onDelete: () => _confirmDeleteSession(
                            session.sessionId, session.title),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── ✅ Empty state: waving CoCo ──────────────────────────────────────────
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Waving mascot — greeting the user
          const RobotMascotBubble(
            expression: RobotExpression.waving,
            size: 100,
          ),
          const SizedBox(height: 12),
          Text(
            "Hi! I'm CoCo 👋",
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your AI productivity assistant.\nAsk me anything or use voice!',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.textTheme.bodySmall?.color),
          ),
        ],
      ),
    );
  }

  // ── Message bubble with expression-aware mascot avatar ───────────────────
  Widget _buildMessageBubble(
      AssistantMessage msg, ThemeData theme, bool isDark) {
    final isUser = msg.isUser;
    final filename = isUser ? null : _extractFilename(msg.content);
    final displayText =
        filename != null ? _cleanContent(msg.content) : msg.content;
    final expression =
        isUser ? RobotExpression.happy : _expressionForMessage(msg);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // ✅ CoCo avatar = robot mascot with expression matching message tone
          if (!isUser) ...[
            RobotMascotBubble(
              expression: expression,
              size: 38,
              transparent: true,
            ),
            const SizedBox(width: 6),
          ],

          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppConstants.primaryBlue
                        : isDark
                            ? const Color(0xFF1E2533)
                            : Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isUser ? 18 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 18),
                    ),
                    boxShadow: isUser
                        ? []
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayText,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isUser
                              ? Colors.white
                              : theme.textTheme.bodyLarge?.color,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (msg.isVoice) ...[
                            Icon(Icons.mic_rounded,
                                size: 10,
                                color: isUser
                                    ? Colors.white60
                                    : theme.textTheme.bodySmall?.color),
                            const SizedBox(width: 3),
                          ],
                          if (msg.timestamp != null)
                            Text(
                              _formatTime(msg.timestamp!),
                              style: TextStyle(
                                fontSize: 10,
                                color: isUser
                                    ? Colors.white60
                                    : theme.textTheme.bodySmall?.color,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Download chip
                if (filename != null) ...[
                  const SizedBox(height: 8),
                  _buildDownloadChip(filename, theme),
                ],
              ],
            ),
          ),

          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildDownloadChip(String filename, ThemeData theme) {
    final parts = filename.split('_');
    final ext = filename.split('.').last;
    final labelParts =
        parts.length > 2 ? parts.sublist(0, parts.length - 2) : parts;
    final label = '${labelParts.join(' ')}.$ext';

    return GestureDetector(
      onTap: () => _downloadFile(filename),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppConstants.primaryBlue,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppConstants.primaryBlue.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.download_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Download Document',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600)),
                  Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_forward_ios_rounded,
                color: Colors.white70, size: 12),
          ],
        ),
      ),
    );
  }

  // ── ✅ Typing indicator: thinking expression ──────────────────────────────
  Widget _buildTypingIndicator(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Thinking mascot while CoCo is typing
          const RobotMascotBubble(
            expression: RobotExpression.thinking,
            size: 38,
            transparent: true,
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E2533) : Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(0),
                const SizedBox(width: 4),
                _dot(200),
                const SizedBox(width: 4),
                _dot(400),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 600 + delayMs),
      curve: Curves.easeInOut,
      builder: (_, value, child) => Opacity(opacity: value, child: child),
      child: Container(
        width: 7,
        height: 7,
        decoration: const BoxDecoration(
          color: AppConstants.primaryBlue,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // ── ✅ UPDATED: Input bar with isSending state ──────────────────────────
  Widget _buildInputBar(
      ThemeData theme, bool isDark, AssistantProvider provider) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.grey.shade200,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2533) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade300,
                  width: 0.5,
                ),
              ),
              child: TextField(
                controller: _controller,
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
                style: theme.textTheme.bodyMedium,
                enabled: !provider.isSending, // ✅ Disable input while sending
                decoration: InputDecoration(
                  hintText: provider.isSending
                      ? 'Sending...'
                      : 'Ask CoCo anything...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── Voice button ──────────────────────────────────────────────────
          GestureDetector(
            onTap: provider.isSending
                ? null
                : _openVoiceScreen, // ✅ Disabled while sending
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2533) : Colors.grey.shade100,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.grey.shade300,
                  width: 0.5,
                ),
              ),
              child: Icon(
                Icons.mic_rounded,
                color: provider.isSending
                    ? (isDark ? Colors.white30 : Colors.grey.shade400)
                    : (isDark ? Colors.white60 : AppConstants.primaryBlue),
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          // ── Send button with isSending state ────────────────────────────
          GestureDetector(
            onTap: provider.isSending
                ? null
                : _sendMessage, // ✅ Disabled while sending
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: provider.isSending
                    ? AppConstants.primaryBlue
                        .withValues(alpha: 0.4) // ✅ visually dimmed
                    : AppConstants.primaryBlue,
                shape: BoxShape.circle,
                boxShadow: provider.isSending
                    ? [] // ✅ No shadow when disabled
                    : [
                        BoxShadow(
                          color:
                              AppConstants.primaryBlue.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: provider.isSending
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.send_rounded,
                      color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $period';
  }
}

// ── Session tile ─────────────────────────────────────────────────────────────

class _SessionTile extends StatelessWidget {
  final ChatSession session;
  final bool isActive;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionTile({
    required this.session,
    required this.isActive,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: isActive
          ? theme.colorScheme.primary.withValues(alpha: 0.08)
          : Colors.transparent,
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          Icons.chat_bubble_outline_rounded,
          size: 20,
          color: isActive
              ? theme.colorScheme.primary
              : theme.textTheme.bodySmall?.color,
        ),
        title: Text(
          session.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? theme.colorScheme.primary : null,
          ),
        ),
        subtitle: session.lastMessagePreview.isNotEmpty
            ? Text(
                session.lastMessagePreview,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: theme.textTheme.bodySmall?.color,
                ),
              )
            : null,
        trailing: IconButton(
          icon: Icon(Icons.delete_outline_rounded,
              size: 18, color: theme.textTheme.bodySmall?.color),
          onPressed: onDelete,
        ),
      ),
    );
  }
}
