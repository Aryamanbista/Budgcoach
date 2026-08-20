import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../network/api_client.dart';

class SmsService {
  static const _methods = MethodChannel('budgcoach/sms');
  static const _events = EventChannel('budgcoach/sms_events');
  static StreamSubscription<dynamic>? _subscription;
  static bool _syncing = false;

  static bool get isAvailable =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<void> initialize() async {
    if (!isAvailable) return;
    _subscription ??= _events.receiveBroadcastStream().listen(
      (_) => syncPendingMessages(),
      onError: (Object error) {
        debugPrint('Financial SMS listener failed: $error');
      },
    );
  }

  static Future<bool> hasPermission() async {
    if (!isAvailable) return false;
    return await _methods.invokeMethod<bool>('hasPermission') ?? false;
  }

  static Future<bool> enable() async {
    if (!isAvailable) return false;
    final granted =
        await _methods.invokeMethod<bool>('requestPermission') ?? false;
    if (granted) await syncPendingMessages();
    return granted;
  }

  static Future<void> syncPendingMessages() async {
    if (!isAvailable || _syncing || !await hasPermission()) return;
    _syncing = true;
    try {
      const storage = FlutterSecureStorage();
      final token = await storage.read(key: 'access_token');
      if (token == null || token.isEmpty) return;

      final rawMessages =
          await _methods.invokeListMethod<dynamic>('getPendingMessages') ??
          const [];
      final messages = rawMessages
          .whereType<Map<dynamic, dynamic>>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => (item['body']?.toString().trim() ?? '').isNotEmpty)
          .toList();
      if (messages.isEmpty) return;

      final dio = Dio(
        BaseOptions(
          baseUrl: ApiClient.baseUrl,
          headers: {'Authorization': 'Bearer $token'},
          connectTimeout: const Duration(seconds: 30),
          receiveTimeout: const Duration(seconds: 30),
        ),
      );
      final accountsResponse = await dio.get('/accounts/');
      final accounts = accountsResponse.data as List<dynamic>;
      final String accountId;
      if (accounts.isEmpty) {
        final created = await dio.post(
          '/accounts/',
          data: {'wallet_name': 'SMS Transactions', 'balance': 0},
        );
        accountId = created.data['id'].toString();
      } else {
        accountId = accounts.first['id'].toString();
      }

      await dio.post(
        '/transactions/sms-sync',
        data: {
          'wallet_type': 'auto',
          'account_id': accountId,
          'messages': messages
              .map(
                (item) =>
                    '${item['sender']?.toString() ?? ''}: ${item['body']}',
              )
              .toList(),
        },
      );
      await _methods.invokeMethod<void>('acknowledgeMessages', {
        'ids': messages.map((item) => item['id'].toString()).toList(),
      });
    } catch (error) {
      debugPrint('Financial SMS sync will retry later: $error');
    } finally {
      _syncing = false;
    }
  }

  static Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}
