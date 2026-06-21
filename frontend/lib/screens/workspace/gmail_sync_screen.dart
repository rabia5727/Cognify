import 'dart:async';
import 'package:flutter/material.dart';
import 'package:frontend/services/oauth_webview.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../providers/gmail_provider.dart';
import '../../services/gmail_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common/app_header.dart';
import '../../utils/ui_feedback.dart';
import '../../config/app_config.dart';

class GmailSyncScreen extends StatefulWidget {
  const GmailSyncScreen({super.key});

  @override
  State<GmailSyncScreen> createState() => _GmailSyncScreenState();
}

class _GmailSyncScreenState extends State<GmailSyncScreen> {
  bool _isConnecting = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final provider = context.read<GmailProvider>();
    await provider.checkConnection();
    if (provider.isConnected) {
      await provider.loadEmails();
    }
  }

  Future<void> _connectGmail() async {
    setState(() => _isConnecting = true);

    try {
      final authData = await GmailService.getMobileAuthUrl();
      final authUrl = authData['auth_url']!;
      final state = authData['state']!;

      // ✅ Use OAuthWebView - same as Classroom - NO manual code paste!
      final success = await OAuthWebView.authenticateWithGoogle(
        context,
        authUrl: authUrl,
        state: state,
        healthEndpoint: '/gmail/health',
      );

      if (success) {
        final provider = context.read<GmailProvider>();
        await provider.checkConnection();
        await provider.loadEmails();
        if (mounted) {
          UIFeedback.showSuccess(context, 'Gmail connected successfully!');
        }
      } else {
        if (mounted) {
          UIFeedback.showError(
              context, 'Failed to connect to Gmail. Please try again.');
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

  Future<void> _syncEmails() async {
    final provider = context.read<GmailProvider>();
    try {
      await provider.syncEmails();
      if (mounted) {
        UIFeedback.showSuccess(context, 'Emails synced successfully!');
      }
    } catch (e) {
      if (mounted) {
        UIFeedback.showError(context, 'Failed to sync: $e');
      }
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
              title: 'Gmail Integration',
              onBack: () => Navigator.pop(context),
            ),
            Expanded(
              child: Consumer<GmailProvider>(
                builder: (context, provider, _) {
                  if (!provider.isConnected) {
                    return _buildConnectScreen(provider);
                  }
                  return _buildEmailListScreen(provider);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectScreen(GmailProvider provider) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.email, size: 80, color: Colors.red.shade400),
          const SizedBox(height: 24),
          const Text(
            'Connect to Gmail',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          Text(
            'Sync your emails and create tasks from actionable emails',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isConnecting ? null : _connectGmail,
              icon: _isConnecting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login),
              label: Text(_isConnecting ? 'Connecting...' : 'Connect Gmail'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailListScreen(GmailProvider provider) {
    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: provider.isSyncing ? null : _syncEmails,
                  icon: provider.isSyncing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync),
                  label:
                      Text(provider.isSyncing ? 'Syncing...' : 'Sync Emails'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                '${provider.emails.length} emails',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              const Spacer(),
              Text(
                '${provider.actionableCount} actionable',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: provider.emails.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.inbox, size: 64, color: Colors.grey.shade300),
                      const SizedBox(height: 16),
                      Text(
                        'No emails synced yet',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: provider.emails.length,
                  itemBuilder: (context, index) {
                    final email = provider.emails[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: email['is_actionable']
                              ? Colors.green.shade100
                              : Colors.grey.shade200,
                          child: Icon(
                            email['is_actionable'] ? Icons.flag : Icons.email,
                            size: 18,
                            color: email['is_actionable']
                                ? Colors.green.shade700
                                : Colors.grey.shade600,
                          ),
                        ),
                        title: Text(
                          email['subject'] ?? 'No Subject',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          email['sender'] ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: email['is_actionable']
                            ? Chip(
                                label: Text(
                                  email['is_task_created']
                                      ? '✅ Task'
                                      : '📌 Action',
                                  style: const TextStyle(fontSize: 10),
                                ),
                                backgroundColor: email['is_task_created']
                                    ? Colors.green.shade100
                                    : Colors.orange.shade100,
                              )
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
