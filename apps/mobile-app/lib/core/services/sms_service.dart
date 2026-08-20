import 'package:flutter/foundation.dart';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:dio/dio.dart';
import '../network/api_client.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Top-level, headless function for background execution
@pragma('vm:entry-point')
void onBackgroundMessage(SmsMessage message) async {
  debugPrint("onBackgroundMessage called: ${message.body}");

  if (message.body == null || message.address == null) return;

  // Basic filter for known bank/wallet sender IDs
  final sender = message.address!.toLowerCase();
  if (sender.contains('esewa') ||
      sender.contains('khalti') ||
      sender.contains('bank')) {
    await SmsService.syncSmsToBackend([message.body!]);
  }
}

class SmsService {
  static final Telephony telephony = Telephony.instance;

  static Future<void> initialize() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

    bool? permissionsGranted = await telephony.requestPhoneAndSmsPermissions;
    if (permissionsGranted != null && permissionsGranted) {
      telephony.listenIncomingSms(
        onNewMessage: (SmsMessage message) {
          debugPrint("Foreground SMS received: ${message.body}");
          if (message.body != null) {
            syncSmsToBackend([message.body!]);
          }
        },
        onBackgroundMessage: onBackgroundMessage,
        listenInBackground: true,
      );
    }
  }

  static Future<void> syncSmsToBackend(List<String> messages) async {
    try {
      // Create a fresh Dio instance since this might run in a background isolate
      final dio = Dio(BaseOptions(baseUrl: ApiClient.baseUrl));

      // Attempt to retrieve token (note: secure storage in background requires careful Android setup,
      // but for demonstration we attempt it)
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'auth_token');

      if (token != null) {
        dio.options.headers['Authorization'] = 'Bearer $token';
      }

      final formData = {
        'wallet_type':
            'esewa', // We can derive this from address in a full implementation
        'account_id':
            '123e4567-e89b-12d3-a456-426614174000', // Dummy UUID for now
        'messages': messages,
      };

      await dio.post('/transactions/sms-sync', data: formData);
      debugPrint("Successfully synced ${messages.length} SMS to backend.");
    } catch (e) {
      debugPrint("Failed to sync SMS to backend: $e");
    }
  }
}
