// lib/screens/assistant/voice_assistant_screen.dart
// The blue orb voice recording screen — matches your Figma design

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../constants/app_constant.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _filePath;

  // Animation controller for orb pulse effect
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Orb pulse animation — scales from 1.0 to 1.08 continuously
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Start recording automatically when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) => _startRecording());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ── Start recording ───────────────────────────────────────────────────────
  Future<void> _startRecording() async {
    // Check microphone permission
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) Navigator.pop(context);
      return;
    }

    // Save audio to temp directory as .m4a
    final dir = await getTemporaryDirectory();
    _filePath =
        '${dir.path}/coco_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _filePath!,
    );

    setState(() => _isRecording = true);
  }

  // ── Stop recording and return file path to AssistantScreen ───────────────
  Future<void> _stopRecording() async {
    setState(() {
      _isRecording = false;
      _isProcessing = true;
    });

    _pulseController.stop();

    final path = await _recorder.stop();

    if (path != null && mounted) {
      // Return file path to AssistantScreen
      // AssistantScreen will call sendVoiceMessage(path)
      Navigator.pop(context, path);
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  // ── Cancel without sending ────────────────────────────────────────────────
  Future<void> _cancel() async {
    await _recorder.stop();
    // Delete the file
    if (_filePath != null) {
      final file = File(_filePath!);
      if (await file.exists()) await file.delete();
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          onPressed: _cancel,
          icon: Icon(Icons.arrow_back_ios_new,
              color: isDark ? Colors.white : Colors.black87),
        ),
        title: Text(
          'Voice Assistant',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.1)
                    : Colors.grey.shade200,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.settings_outlined,
                  size: 18, color: isDark ? Colors.white70 : Colors.black54),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          const Spacer(),

          // ── Animated blue orb ─────────────────────────────────────────
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (_, child) => Transform.scale(
              scale: _isRecording ? _pulseAnimation.value : 1.0,
              child: child,
            ),
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF5B9BF8), // light blue center
                    AppConstants.primaryBlue, // deeper blue edge
                    const Color(0xFF1A4FC4), // dark blue outer
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppConstants.primaryBlue.withOpacity(0.4),
                    blurRadius: _isRecording ? 40 : 20,
                    spreadRadius: _isRecording ? 10 : 4,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 40),

          // ── Status text ───────────────────────────────────────────────
          Text(
            _isProcessing
                ? 'Processing...'
                : _isRecording
                    ? 'Listening...'
                    : 'Starting...',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),

          const SizedBox(height: 12),

          // ── Hint text ─────────────────────────────────────────────────
          Text(
            '"Try saying \'Add meeting with Design team\'"',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black45,
            ),
            textAlign: TextAlign.center,
          ),

          const Spacer(),

          // ── Quick action buttons — from your Figma ────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _quickActionButton(Icons.add_task_rounded, 'Add Task',
                    command: 'Add a task for tomorrow'),
                const SizedBox(width: 12),
                _quickActionButton(Icons.alarm_rounded, 'Set Reminder',
                    command: 'Set a reminder for meeting'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _quickActionButton(Icons.calendar_today_rounded, 'Summarize Day',
              command: 'Summarize my tasks for today'),

          const SizedBox(height: 40),

          // ── Stop button — tap to stop recording ───────────────────────
          GestureDetector(
            onTap: _isRecording ? _stopRecording : null,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color:
                    _isRecording ? Colors.red.shade400 : Colors.grey.shade400,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isProcessing
                    ? Icons.hourglass_empty_rounded
                    : Icons.stop_rounded,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),

          const SizedBox(height: 12),

          Text(
            'Tap to stop',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),

          const SizedBox(height: 48),
        ],
      ),
    );
  }

  // Quick action chip button — matches Figma design
  Widget _quickActionButton(IconData icon, String label, {String? command}) {
    return GestureDetector(
      onTap: () async {
        // Stop recording first if active
        if (_isRecording) {
          await _recorder.stop();
          _pulseController.stop();
          setState(() => _isRecording = false);
        }
        // Return the command as if it was spoken
        if (mounted) Navigator.pop(context, command ?? label);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppConstants.primaryBlue.withOpacity(0.4)),
          borderRadius: BorderRadius.circular(24),
          color: AppConstants.primaryBlue.withOpacity(0.08),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: AppConstants.primaryBlue),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: AppConstants.primaryBlue,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
