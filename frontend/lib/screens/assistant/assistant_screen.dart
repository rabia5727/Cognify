// lib/screens/assistant/assistant_screen.dart
// Main AI chat screen — matches your Figma design

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../providers/assistant_provider.dart';
import '../../models/assistant_model.dart';
import '../../constants/app_constant.dart';
import 'voice_assistant_screen.dart'; // Updated import name

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

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
    // Load conversation history when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AssistantProvider>().loadHistory();
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

  // Scroll to bottom after new message
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

  // Send text message
  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final provider = context.read<AssistantProvider>();
    await provider.sendMessage(text, source: 'text');
    _scrollToBottom();

    // Wait for AI reply to be added, then speak
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final messages = provider.messages;
      if (messages.isNotEmpty && messages.last.role == 'assistant') {
        _tts.speak(messages.last.content);
      }
    });
  }

  // Open voice assistant screen (renamed from VoiceListeningScreen)
  Future<void> _openVoiceScreen() async {
    final result = await Navigator.push<String>(
      context,
      MaterialPageRoute(
          builder: (_) => const VoiceAssistantScreen()), // Updated class name
    );

    // result is the audio file path or quick command text returned from VoiceAssistantScreen
    if (result != null && mounted) {
      final provider = context.read<AssistantProvider>();

      // Check if result is a quick command (text) or file path
      if (result.startsWith('/') || result.contains('.m4a')) {
        // It's a file path from recording
        await provider.sendVoiceMessage(result);
      } else {
        // It's a quick command text
        await provider.sendMessage(result, source: 'voice');
      }

      _scrollToBottom();

      // Wait for AI reply to be added, then speak
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final messages = provider.messages;
        if (messages.isNotEmpty && messages.last.role == 'assistant') {
          _tts.speak(messages.last.content);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_ios_new,
              color: theme.textTheme.bodyLarge?.color),
        ),
        title: Text(
          'AI Assistant',
          style: theme.textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        actions: [
          // Mic icon in top right — matches your Figma
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: GestureDetector(
              onTap: _openVoiceScreen,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.grey.shade200,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mic_rounded,
                    size: 20, color: theme.textTheme.bodyLarge?.color),
              ),
            ),
          ),
        ],
      ),
      body: Consumer<AssistantProvider>(
        builder: (context, provider, _) {
          // Scroll to bottom when messages change
          if (provider.messages.isNotEmpty) _scrollToBottom();

          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              // ── Chat messages list ──────────────────────────────────────
              Expanded(
                child: provider.messages.isEmpty
                    ? _buildEmptyState(theme)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        itemCount: provider.messages.length +
                            (provider.isTyping ? 1 : 0),
                        itemBuilder: (context, index) {
                          // Show typing indicator as last item
                          if (provider.isTyping &&
                              index == provider.messages.length) {
                            return _buildTypingIndicator(theme, isDark);
                          }
                          return _buildMessageBubble(
                              provider.messages[index], theme, isDark);
                        },
                      ),
              ),

              // ── Bottom input bar ────────────────────────────────────────
              _buildInputBar(theme, isDark),
            ],
          );
        },
      ),
    );
  }

  // ── Empty state when no messages yet ─────────────────────────────────────
  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppConstants.primaryBlue.withOpacity(0.1),
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

  // ── Single message bubble ─────────────────────────────────────────────────
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
          // AI avatar — only for assistant messages
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

          // Message bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppConstants.primaryBlue
                    : isDark
                        ? Colors.white.withOpacity(0.08)
                        : Colors.grey.shade100,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
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
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Voice indicator — small mic icon on voice messages
                      if (msg.isVoice) ...[
                        Icon(Icons.mic_rounded,
                            size: 10,
                            color: isUser
                                ? Colors.white60
                                : theme.textTheme.bodySmall?.color),
                        const SizedBox(width: 4),
                      ],
                      // Timestamp
                      if (msg.timestamp != null)
                        Text(
                          _formatTime(msg.timestamp!),
                          style: theme.textTheme.bodySmall?.copyWith(
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

          // User avatar placeholder — only for user messages
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }

  // ── Typing indicator — 3 dots animation ──────────────────────────────────
  Widget _buildTypingIndicator(ThemeData theme, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
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
              color: isDark
                  ? Colors.white.withOpacity(0.08)
                  : Colors.grey.shade100,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dot(0),
                const SizedBox(width: 4),
                _dot(150),
                const SizedBox(width: 4),
                _dot(300),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Animated dot for typing indicator
  Widget _dot(int delayMs) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1.0),
      duration: const Duration(milliseconds: 600),
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

  // ── Bottom input bar ──────────────────────────────────────────────────────
  Widget _buildInputBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color:
                isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          // Text input field
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.08)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      decoration: InputDecoration(
                        hintText: 'Ask AI anything...',
                        hintStyle: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodySmall?.color,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                      textInputAction: TextInputAction.send,
                      maxLines: null, // allow multi-line
                    ),
                  ),
                  // Mic icon inside input field
                  IconButton(
                    onPressed: _openVoiceScreen,
                    icon: Icon(Icons.mic_none_rounded,
                        color: theme.textTheme.bodySmall?.color),
                    iconSize: 22,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Send button — blue circle
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppConstants.primaryBlue,
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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
