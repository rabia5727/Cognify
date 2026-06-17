import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ for kIsWeb
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'token_storage.dart';
import 'dart:convert';

class OAuthWebView {
  static Future<bool> authenticateWithGoogle(
    BuildContext context, {
    required String authUrl,
    required String state,
  }) async {
    // ✅ On web — open in browser tab
    if (kIsWeb) {
      return await _authenticateWeb(context, authUrl: authUrl, state: state);
    }

    // On mobile — use WebView
    return await _authenticateMobile(context, authUrl: authUrl, state: state);
  }

  // ── Web flow (Chrome) ──────────────────────────────────────────
  static Future<bool> _authenticateWeb(
    BuildContext context, {
    required String authUrl,
    required String state,
  }) async {
    final completer = Completer<bool>();

    // Open Google OAuth in new tab
    final uri = Uri.parse(authUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    // Show dialog asking user to confirm when done
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Connect Google Classroom'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.open_in_browser, size: 48, color: Color(0xFF1360E2)),
              SizedBox(height: 16),
              Text(
                'A browser tab has opened for Google Sign In.\n\nAfter signing in, come back here and tap "Done".',
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                completer.complete(false);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                // Check if actually connected
                final connected = await _verifyConnection();
                completer.complete(connected);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1360E2),
              ),
              child:
                  const Text('Done ✓', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }

    return completer.future;
  }

  // ── Mobile flow (Android/iOS) ──────────────────────────────────
  static Future<bool> _authenticateMobile(
    BuildContext context, {
    required String authUrl,
    required String state,
  }) async {
    // Only import webview on mobile
    // This avoids web compilation errors
    final completer = Completer<bool>();

    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => Dialog(
          insetPadding: EdgeInsets.zero,
          child: SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: _MobileWebView(
              authUrl: authUrl,
              state: state,
              onResult: (success) {
                completer.complete(success);
                Navigator.pop(ctx);
              },
            ),
          ),
        ),
      );
    }

    return completer.future;
  }

  static Future<bool> _verifyConnection() async {
    try {
      final token = await TokenStorage.getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}/classroom/health'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['connected'] ?? false;
      }
    } catch (e) {
      print('Verify connection error: $e');
    }
    return false;
  }
}

// ── Mobile WebView Widget ──────────────────────────────────────────
class _MobileWebView extends StatefulWidget {
  final String authUrl;
  final String state;
  final Function(bool) onResult;

  const _MobileWebView({
    required this.authUrl,
    required this.state,
    required this.onResult,
  });

  @override
  State<_MobileWebView> createState() => _MobileWebViewState();
}

class _MobileWebViewState extends State<_MobileWebView> {
  @override
  Widget build(BuildContext context) {
    // Import WebView conditionally for mobile only
    return const Center(
      child: Text('WebView not available'),
    );
  }
}
