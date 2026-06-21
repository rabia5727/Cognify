import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:frontend/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'token_storage.dart';

class OAuthWebView {
  static Future<bool> authenticateWithGoogle(
    BuildContext context, {
    required String authUrl,
    required String state,
    String healthEndpoint = '/gmail/health',
  }) async {
    // ✅ Use different approach for web vs mobile
    if (kIsWeb) {
      return await _authenticateWeb(
        context,
        authUrl: authUrl,
        state: state,
        healthEndpoint: healthEndpoint,
      );
    } else {
      return await _authenticateMobile(
        context,
        authUrl: authUrl,
        state: state,
        healthEndpoint: healthEndpoint,
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  // WEB: Use url_launcher + manual Done button
  // ─────────────────────────────────────────────────────────────
  static Future<bool> _authenticateWeb(
    BuildContext context, {
    required String authUrl,
    required String state,
    required String healthEndpoint,
  }) async {
    final completer = Completer<bool>();

    // Open in new browser tab
    final uri = Uri.parse(authUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      return false;
    }

    // Show dialog with Done button
    if (context.mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('Connect Google Account'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.open_in_browser, size: 48, color: Color(0xFF1360E2)),
              SizedBox(height: 16),
              Text(
                'Google Sign In opened in your browser.\n\n'
                'After signing in, return to the app and tap "Done".',
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
                // Check if connected
                final connected = await _checkConnection(healthEndpoint);
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

  // ─────────────────────────────────────────────────────────────
  // MOBILE: Use WebView (Android/iOS)
  // ─────────────────────────────────────────────────────────────
  static Future<bool> _authenticateMobile(
    BuildContext context, {
    required String authUrl,
    required String state,
    required String healthEndpoint,
  }) async {
    final completer = Completer<bool>();

    // Initialize WebView for mobile
    final controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: (request) {
            final url = request.url;
            if (url.contains('/oauth/mobile-callback')) {
              final uri = Uri.parse(url);
              final code = uri.queryParameters['code'];
              final callbackState = uri.queryParameters['state'];

              if (code != null && callbackState != null) {
                _handleCallback(
                  code,
                  callbackState,
                  completer,
                  context,
                  healthEndpoint,
                );
              }
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(authUrl));

    // Show WebView dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        insetPadding: EdgeInsets.zero,
        child: Container(
          width: double.infinity,
          height: double.infinity,
          child: Column(
            children: [
              AppBar(
                title: const Text(
                  'Google Sign In',
                  style: TextStyle(color: Colors.white),
                ),
                backgroundColor: const Color(0xFF1360E2),
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () {
                    if (!completer.isCompleted) {
                      completer.complete(false);
                    }
                    Navigator.pop(context);
                  },
                ),
              ),
              Expanded(
                child: WebViewWidget(controller: controller),
              ),
            ],
          ),
        ),
      ),
    );

    return await completer.future;
  }

  // ─────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────
  static Future<void> _handleCallback(
    String code,
    String state,
    Completer<bool> completer,
    BuildContext context,
    String healthEndpoint,
  ) async {
    try {
      final token = await TokenStorage.getToken();

      final response = await http.get(
        Uri.parse(
            '${AppConfig.baseUrl}/classroom/oauth/mobile-callback?code=$code&state=$state'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      );

      if (context.mounted) {
        Navigator.pop(context);
      }

      if (response.statusCode == 200) {
        final connected = await _checkConnection(healthEndpoint);
        completer.complete(connected);
      } else {
        completer.complete(false);
      }
    } catch (e) {
      print('❌ Callback error: $e');
      if (context.mounted) {
        Navigator.pop(context);
      }
      completer.complete(false);
    }
  }

  static Future<bool> _checkConnection(String healthEndpoint) async {
    try {
      final token = await TokenStorage.getToken();
      final response = await http.get(
        Uri.parse('${AppConfig.baseUrl}$healthEndpoint'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['connected'] ?? false;
      }
    } catch (e) {
      print('Connection check error: $e');
    }
    return false;
  }
}
