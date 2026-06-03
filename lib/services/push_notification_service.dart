import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../main.dart'; // Import to access global rootNavigatorKey for SnackBar feedback

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel_v2', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.',
    importance: Importance.max,
    playSound: true,
  );

  void _showVisualFeedback(String message, {bool isError = false}) {
    try {
      final context = rootNavigatorKey.currentState?.overlay?.context;
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          )
        );
      }
    } catch (e) {
      debugPrint("Error showing feedback SnackBar: $e");
    }
  }

  Future<void> initialize() async {
    // 1. Request permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional) {
      debugPrint('User granted permission: ${settings.authorizationStatus}');
      await saveTokenToSupabase();
    } else {
      debugPrint('User declined/has not accepted permission: ${settings.authorizationStatus}');
    }
// ... remaining lines will be matched by the tool ...

    // 2. Initialize Local Notifications (Required for Foreground pop-ups on Android + iOS)
    if (!kIsWeb) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      // iOS-specific initialization (required for local notifications on iOS)
      const DarwinInitializationSettings initializationSettingsIOS =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('Notification tapped (foreground): ${response.payload}');
        },
      );

      // Create the High Importance channel (Android only)
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }

    // 3. Handle messages when the app is in the FOREGROUND
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      if (notification != null) {
        showLocalNotification(
          title: notification.title ?? "New Notification",
          body: notification.body ?? "",
        );
      }
      debugPrint('Foreground Message: ${notification?.title}');
    });

    // 4. Handle when app is opened from a BACKGROUND notification tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('App opened from background notification: ${message.notification?.title}');
      // Navigation is handled by the root navigator if needed
    });

    // 5. Handle when app is opened from TERMINATED state via notification tap
    final RemoteMessage? initialMessage = await _fcm.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App launched from terminated notification: ${initialMessage.notification?.title}');
    }

    // 6. Handle token refresh
    _fcm.onTokenRefresh.listen((newToken) {
      _updateTokenInSupabase(newToken);
    });
  }

  Future<void> showLocalNotification({required String title, required String body}) async {
    if (kIsWeb) return;

    final BigTextStyleInformation bigTextStyleInformation = BigTextStyleInformation(
      body,
      contentTitle: title,
      summaryText: 'Translation Update',
    );

    await _notificationsPlugin.show(
      title.hashCode,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.max,
          priority: Priority.high,
          styleInformation: bigTextStyleInformation,
          ticker: 'ticker',
          icon: '@mipmap/ic_launcher',
          category: AndroidNotificationCategory.message,
          groupKey: 'com.geez.script.MESSAGES',
          playSound: true,
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          interruptionLevel: InterruptionLevel.active,
        ),
      ),
    );
  }

  Future<void> saveTokenToSupabase() async {
    try {
      // Get the token
      String? token = await _fcm.getToken();
      if (token != null) {
        debugPrint('FCM Token acquired successfully.');
        await _updateTokenInSupabase(token);
      } else {
        debugPrint('FCM Token is NULL. Check Google Play Services.');
      }
    } catch (e) {
      debugPrint("Error getting FCM token: $e");
    }
  }

  Future<void> _updateTokenInSupabase(String fcmToken) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint("Cannot save FCM token: User not logged in.");
        return;
      }

      String platform;
      if (kIsWeb) {
        platform = 'web';
      } else if (Platform.isIOS) {
        platform = 'ios';
      } else if (Platform.isAndroid) {
        platform = 'android';
      } else {
        platform = 'unknown';
      }

      // Call a backend RPC function to safely reassign the token
      // This bypasses the RLS conflict when multiple accounts log in on the same physical phone.
      await _supabase.rpc('register_device_token', params: {
        'fcm_token_param': fcmToken,
        'platform_param': platform,
      });
      
      debugPrint("Successfully saved FCM token to Supabase via RPC.");

    } catch (e) {
      debugPrint("Error saving FCM token to Supabase: $e");
    }
  }

  // Use this specifically to clear token on logout
  Future<void> clearTokenOnLogout() async {
     try {
      String? token = await _fcm.getToken();
      if(token != null) {
         await _supabase.from('user_devices').delete().eq('fcm_token', token);
      }
    } catch (e) {
      debugPrint("Error clearing FCM token: $e");
    }
  }
}
