// lib/screens/assistant/assistant_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../../providers/assistant_provider.dart';
import '../../models/assistant_model.dart';
import '../../constants/app_constant.dart';
import '../../widgets/common/app_header.dart';
import 'voice_assistant_screen.dart';

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'AI Assistant',
              onBack: () => Navigator.pop(context),
            ),

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

            // ── FIXED Input Bar ─────────────────────────────────────────
            _buildInputBar(theme, isDark),
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
                          color: Colors.black.withOpacity(0.06),
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
                  color: Colors.black.withOpacity(0.06),
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

  // ── FIXED Input Bar - Placeholder inside, proper styling ────────────────
  Widget _buildInputBar(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(
            color:
                isDark ? Colors.white.withOpacity(0.08) : Colors.grey.shade200,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          // Text field with proper border and placeholder inside
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E2533) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
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

          // Mic button
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
                      ? Colors.white.withOpacity(0.1)
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

          // Send button
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
                    color: AppConstants.primaryBlue.withOpacity(0.3),
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
