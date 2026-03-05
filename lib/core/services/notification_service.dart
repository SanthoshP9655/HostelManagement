// lib/core/services/notification_service.dart
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Background handler - fired when app is terminated
  debugPrint('BG message: ${message.notification?.title}');
}

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  String? _currentToken;
  Function(String route)? _onNavigate;

  void setNavigationCallback(Function(String route) callback) =>
      _onNavigate = callback;

  // ── Initialization ────────────────────────────────────────
  Future<void> initialize() async {
    // Register background handler
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    }

    // Request permission
    final settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM Permission: ${settings.authorizationStatus}');

    // Local notifications setup (Android/iOS)
    if (!kIsWeb) {
      const androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const iosSettings = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );
      await _localNotifications.initialize(
        const InitializationSettings(
            android: androidSettings, iOS: iosSettings),
        onDidReceiveNotificationResponse: _onNotificationTap,
      );

      // Android notification channel
      const channel = AndroidNotificationChannel(
        'hostel_high_importance',
        'Hostel Notifications',
        description: 'Notifications from SmartHostel',
        importance: Importance.max,
        playSound: true,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }

    // Foreground message handler
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Notification click when app in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

    // Notification click when app was terminated
    final initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) _handleMessageOpenedApp(initialMessage);

    // Get and store token
    await refreshToken();
  }

  // ── Token Management ─────────────────────────────────────
  Future<String?> refreshToken() async {
    if (kIsWeb) {
      // Web: use getToken with vapid key (optional for web)
      _currentToken = await _fcm.getToken();
    } else {
      _currentToken = await _fcm.getToken();
    }
    debugPrint('FCM Token: $_currentToken');
    return _currentToken;
  }

  Future<void> saveToken({
    required String userId,
    required String role,
    required String collegeId,
  }) async {
    final token = _currentToken ?? await refreshToken();
    if (token == null) return;
    try {
      await SupabaseService.instance.deviceTokens.upsert({
        'user_id': userId,
        'role': role,
        'college_id': collegeId,
        'fcm_token': token,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'user_id,role');
    } catch (e) {
      debugPrint('Save token error: $e');
    }
  }

  // ── Foreground Handler ────────────────────────────────────
  void _handleForegroundMessage(RemoteMessage message) {
    if (kIsWeb) return;
    
    final notification = message.notification;
    if (notification == null) return;

    _localNotifications.show(
      notification.hashCode,
      notification.title,
      notification.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'hostel_high_importance',
          'Hostel Notifications',
          channelDescription: 'Notifications from SmartHostel',
          importance: Importance.max,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.data['route'],
    );
  }

  void _handleMessageOpenedApp(RemoteMessage message) {
    final route = message.data['route'];
    if (route != null && _onNavigate != null) {
      _onNavigate!(route);
    }
  }

  void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null && _onNavigate != null) {
      _onNavigate!(response.payload!);
    }
  }

  // ── Send Notification via Supabase Edge Function ──────────
  Future<void> sendNotification({
    required List<String> recipientIds,
    required String role,
    required String title,
    required String body,
    required String route,
    required String collegeId,
  }) async {
    try {
      // Get FCM tokens from device_tokens table
      final rows = await SupabaseService.instance.deviceTokens
          .select('fcm_token')
          .eq('college_id', collegeId)
          .eq('role', role)
          .inFilter('user_id', recipientIds);

      final tokens = (rows as List)
          .map((r) => r['fcm_token'] as String)
          .toList();
      if (tokens.isEmpty) return;

      // Call Supabase Edge Function to send FCM (avoids exposing server key)
      await SupabaseService.instance.client.functions.invoke(
        'send-notification',
        body: {
          'tokens': tokens,
          'title': title,
          'body': body,
          'data': {'route': route},
        },
      );
    } catch (e) {
      debugPrint('Send notification error: $e');
    }
  }
}
