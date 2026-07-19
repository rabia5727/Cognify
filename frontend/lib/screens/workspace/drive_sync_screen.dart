import 'package:flutter/material.dart';
import 'package:frontend/services/oauth_webview.dart';
import 'package:provider/provider.dart';

import '../../providers/profile_provider.dart';
import '../../services/google_drive_service.dart';
import '../../utils/ui_feedback.dart';
import '../../widgets/common/app_header.dart';

class DriveSyncScreen extends StatefulWidget {
  const DriveSyncScreen({super.key});

  @override
  State<DriveSyncScreen> createState() => _DriveSyncScreenState();
}

class _DriveSyncScreenState extends State<DriveSyncScreen> {
  bool _isConnecting = false;
  bool _isConnected = false;

  @override
  void initState() {
    super.initState();
    _checkConnection();
  }

  Future<void> _checkConnection() async {
    try {
      final isConnected = await GoogleDriveService.isConnected();
      setState(() => _isConnected = isConnected);
    } catch (e) {
      setState(() => _isConnected = false);
    }
  }

  Future<void> _connectDrive() async {
    setState(() => _isConnecting = true);

    try {
      final authData = await GoogleDriveService.getMobileAuthUrl();
      final authUrl = authData['auth_url']!;
      final state = authData['state']!;

      final success = await OAuthWebView.authenticateWithGoogle(
        context,
        authUrl: authUrl,
        state: state,
        healthEndpoint: '/drive/health',
      );

      if (success) {
        await _checkConnection();
        if (mounted) {
          // Refresh profile connections
          context.read<ProfileProvider>().loadConnections();
          UIFeedback.showSuccess(
              context, 'Google Drive connected successfully!');
        }
      } else {
        if (mounted) {
          UIFeedback.showError(context, 'Failed to connect Google Drive');
        }
      }
    } catch (e) {
      if (mounted) {
        UIFeedback.showError(context, 'Failed to connect: $e');
      }
    } finally {
      setState(() => _isConnecting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            AppHeader(
              title: 'Google Drive',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.drive_folder_upload_outlined,
                      size: 80,
                      color: Colors.blue.shade400,
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Connect to Google Drive',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Upload files and submit assignments to Google Classroom',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 32),
                    if (_isConnected) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle, color: Colors.green),
                            SizedBox(width: 10),
                            Text(
                              'Google Drive is connected!',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _isConnecting ? null : _connectDrive,
                        icon: _isConnecting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.login),
                        label: Text(_isConnecting
                            ? 'Connecting...'
                            : _isConnected
                                ? 'Reconnect Drive'
                                : 'Connect Google Drive'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                      ),
                    ),
                    if (_isConnected) ...[
                      const SizedBox(height: 12),
                      Text(
                        'You can now upload files for assignment submission',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
