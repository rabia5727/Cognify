// lib/screens/assistant/voice_assistant_screen.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../constants/app_constant.dart';
import '../../widgets/common/app_header.dart';
import 'assistant_screen.dart';

class VoiceAssistantScreen extends StatefulWidget {
  const VoiceAssistantScreen({super.key});

  @override
  State<VoiceAssistantScreen> createState() => _VoiceAssistantScreenState();
}

class _VoiceAssistantScreenState extends State<VoiceAssistantScreen>
    with TickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _filePath;

  // Orb pulse — scale animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Rings — expand outward when listening
  late AnimationController _ringController;
  late Animation<double> _ring1Animation;
  late Animation<double> _ring2Animation;
  late Animation<double> _ring3Animation;

  @override
  void initState() {
    super.initState();

    // Orb pulse
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Rings — staggered expand + fade
    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _ring1Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ringController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );
    _ring2Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ringController,
        curve: const Interval(0.2, 0.9, curve: Curves.easeOut),
      ),
    );
    _ring3Animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ringController,
        curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) => _startRecording());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _ringController.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) {
      if (mounted) Navigator.pop(context);
      return;
    }

    final dir = await getTemporaryDirectory();
    _filePath = '${dir.path}/coco_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: _filePath!,
    );

    setState(() => _isRecording = true);
  }

  Future<void> _stopRecording() async {
    setState(() {
      _isRecording = false;
      _isProcessing = true;
    });
    _pulseController.stop();
    _ringController.stop();

    final path = await _recorder.stop();
    if (path != null && mounted) {
      Navigator.pop(context, path);
    } else {
      if (mounted) Navigator.pop(context);
    }
  }

  Future<void> _cancel() async {
    await _recorder.stop();
    if (_filePath != null) {
      final file = File(_filePath!);
      if (await file.exists()) await file.delete();
    }
    if (mounted) Navigator.pop(context);
  }

  // Switch to chat screen smoothly
  Future<void> _switchToChat() async {
    await _recorder.stop();
    if (_filePath != null) {
      final file = File(_filePath!);
      if (await file.exists()) await file.delete();
    }
    if (mounted) {
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const AssistantScreen(),
          transitionsBuilder: (_, animation, __, child) =>
              FadeTransition(opacity: animation, child: child),
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
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
            // ── AppHeader — matches all other screens ─────────────────
            AppHeader(
              title: 'Voice Assistant',
              onBack: _cancel,
              // Chat icon on right — tap to switch to chat
              actions: [
                GestureDetector(
                  onTap: _switchToChat,
                  child: Container(
                    width: 36,
                    height: 36,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.1)
                          : Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chat_bubble_outline_rounded,
                      size: 18,
                      color: isDark ? Colors.white70 : Colors.grey.shade700,
                    ),
                  ),
                ),
              ],
            ),

            const Spacer(),

            // ── Orb with expanding rings ──────────────────────────────
            SizedBox(
              width: 280,
              height: 280,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Ring 3 — outermost, most transparent
                  if (_isRecording)
                    AnimatedBuilder(
                      animation: _ring3Animation,
                      builder: (_, __) => Container(
                        width: 200 + (_ring3Animation.value * 70),
                        height: 200 + (_ring3Animation.value * 70),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppConstants.primaryBlue.withOpacity(
                                0.12 * (1 - _ring3Animation.value)),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                  // Ring 2
                  if (_isRecording)
                    AnimatedBuilder(
                      animation: _ring2Animation,
                      builder: (_, __) => Container(
                        width: 200 + (_ring2Animation.value * 50),
                        height: 200 + (_ring2Animation.value * 50),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppConstants.primaryBlue
                                .withOpacity(0.2 * (1 - _ring2Animation.value)),
                            width: 1.5,
                          ),
                        ),
                      ),
                    ),

                  // Ring 1 — closest to orb
                  if (_isRecording)
                    AnimatedBuilder(
                      animation: _ring1Animation,
                      builder: (_, __) => Container(
                        width: 200 + (_ring1Animation.value * 30),
                        height: 200 + (_ring1Animation.value * 30),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppConstants.primaryBlue
                                .withOpacity(0.3 * (1 - _ring1Animation.value)),
                            width: 2,
                          ),
                        ),
                      ),
                    ),

                  // The orb itself
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, child) => Transform.scale(
                      scale: _isRecording ? _pulseAnimation.value : 1.0,
                      child: child,
                    ),
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const RadialGradient(
                          colors: [
                            Color(0xFF7BB8FF), // light blue center
                            Color(0xFF2563EB), // mid blue
                            Color(0xFF1A4FC4), // dark blue edge
                          ],
                          stops: [0.0, 0.55, 1.0],
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppConstants.primaryBlue
                                .withOpacity(_isRecording ? 0.5 : 0.2),
                            blurRadius: _isRecording ? 50 : 20,
                            spreadRadius: _isRecording ? 8 : 2,
                          ),
                        ],
                      ),
                      // Mic icon inside orb — colored, visible
                      child: Icon(
                        _isProcessing
                            ? Icons.hourglass_empty_rounded
                            : Icons.mic_rounded,
                        color: Colors.white.withOpacity(0.9),
                        size: 56,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // ── Status text ───────────────────────────────────────────
            Text(
              _isProcessing
                  ? 'Processing...'
                  : _isRecording
                      ? 'Listening...'
                      : 'Starting...',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              '"Try saying \'Add meeting with Design team\'"',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
              textAlign: TextAlign.center,
            ),

            const Spacer(),

            // ── Quick action chips ────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _chip(Icons.add_task_rounded, 'Add Task'),
                  const SizedBox(width: 12),
                  _chip(Icons.alarm_rounded, 'Set Reminder'),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _chip(Icons.calendar_today_rounded, 'Summarize Day'),

            const SizedBox(height: 32),

            // ── Stop button ───────────────────────────────────────────
            GestureDetector(
              onTap: _isRecording ? _stopRecording : null,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color:
                      _isRecording ? Colors.red.shade400 : Colors.grey.shade400,
                  shape: BoxShape.circle,
                  boxShadow: _isRecording
                      ? [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            blurRadius: 16,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
                child: const Icon(
                  Icons.stop_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Tap to stop',
              style: theme.textTheme.bodySmall,
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        border: Border.all(
            color: AppConstants.primaryBlue.withOpacity(0.35), width: 1),
        borderRadius: BorderRadius.circular(20),
        color: AppConstants.primaryBlue.withOpacity(0.07),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppConstants.primaryBlue),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  color: AppConstants.primaryBlue,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
