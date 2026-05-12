import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PushNotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  // Create a High Importance channel for Android
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel', // id
    'High Importance Notifications', // title
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
    playSound: true,
  );

  Future<void> initialize() async {
    // 1. Request permission
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('User granted permission');
      await saveTokenToSupabase();
    }

    // 2. Initialize Local Notifications (Required for Foreground pop-ups on Android)
    if (!kIsWeb) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
      );
      await _notificationsPlugin.initialize(initializationSettings);

      // Create the High Importance channel
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(_channel);
    }
    // 3. Handle messages when the app is in the foreground
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

    // 4. Handle token refresh
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
        await _updateTokenInSupabase(token);
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
