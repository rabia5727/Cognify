// lib/screens/assistant/assistant_screen.dart
//
// ✅ SESSION REWRITE: added a sidebar (Drawer) listing all chat
// sessions, a "+ New Chat" action, and session-aware history loading.
// This is the UI fix for "history of chat should show in separate
// chats, not one single chat".

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../providers/assistant_provider.dart';
import '../../models/assistant_model.dart';
import '../../services/assistant_service.dart';
import '../../constants/app_constant.dart';
import 'voice_assistant_screen.dart';

class AssistantScreen extends StatefulWidget {
  final String? initialMessage;
  // ✅ NEW: optionally open directly into a specific existing chat
  // (e.g. tapping a session from a notification or deep link).
  final String? sessionId;

  const AssistantScreen({super.key, this.initialMessage, this.sessionId});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends State<AssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FlutterTts _tts = FlutterTts();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = context.read<AssistantProvider>();

      // ✅ Load the specific session if one was passed, otherwise start
      // fresh (a brand-new chat — matches "Yes" button flow from
      // dashboard, which should open a NEW conversation, not append to
      // whatever was open before).
      if (widget.sessionId != null) {
        await provider.loadHistory(sessionId: widget.sessionId);
      } else {
        await provider.startNewChat();
      }

      // Load sidebar list in background regardless
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      drawer: _buildSessionDrawer(theme, isDark),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeaderWithMenu(theme),
            Expanded(
              child: Consumer<AssistantProvider>(
                builder: (context, provider, _) {
                  if (provider.messages.isNotEmpty) _scrollToBottom();
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return provider.messages.isEmpty
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
                        );
                },
              ),
            ),
            _buildInputBar(theme, isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderWithMenu(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 12, 4),
      child: Row(
        children: [
          Builder(
            builder: (ctx) => IconButton(
              onPressed: () => Scaffold.of(ctx).openDrawer(),
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
          ),
          Expanded(
            child: Consumer<AssistantProvider>(
              builder: (context, provider, _) => Text(
                provider.currentTitle,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _startNewChat,
            icon: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded,
                  color: theme.colorScheme.primary, size: 20),
            ),
          ),
        ],
      ),
    );
  }

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
                  Text(
                    'Your Chats',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
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
                          'No chats yet. Start a new conversation with CoCo!',
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

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppConstants.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 40, color: AppConstants.primaryBlue),
          ),
          const SizedBox(height: 16),
          Text('Hi! I\'m CoCo 👋',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
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

  Widget _buildMessageBubble(
      AssistantMessage msg, ThemeData theme, bool isDark) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: AppConstants.primaryBlue,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    msg.content,
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
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildTypingIndicator(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppConstants.primaryBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
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

  Widget _buildInputBar(ThemeData theme, bool isDark) {
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
                decoration: InputDecoration(
                  hintText: 'Ask AI anything...',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
                textInputAction: TextInputAction.send,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _openVoiceScreen,
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
                color: isDark ? Colors.white60 : AppConstants.primaryBlue,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppConstants.primaryBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppConstants.primaryBlue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
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

// ─────────────────────────────────────────────────────────────────────────
// ✅ NEW: Session list tile for the sidebar
// ─────────────────────────────────────────────────────────────────────────

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
