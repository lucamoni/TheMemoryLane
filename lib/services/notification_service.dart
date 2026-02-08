import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Servizio per la gestione delle notifiche locali.
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  static NotificationService get instance => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Inizializza il plugin delle notifiche per Android e iOS.
  Future<void> init() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/launcher_icon');
    const DarwinInitializationSettings iOSSettings =
        DarwinInitializationSettings();

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iOSSettings,
    );

    await _notificationsPlugin.initialize(initSettings);
  }

  /// Mostra una notifica immediata.
  Future<int> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'geofence_notifications',
          'Notifiche Geofence',
          channelDescription: 'Notifiche quando entri in aree geofenced',
          importance: Importance.max,
          priority: Priority.high,
        );

    const DarwinNotificationDetails iOSDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iOSDetails,
    );

    final int id = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _notificationsPlugin.show(id, title, body, details, payload: payload);
    return id;
  }

  /// Annulla una specifica notifica tramite ID.
  Future<void> cancelNotification(int id) async {
    await _notificationsPlugin.cancel(id);
  }

  /// Annulla tutte le notifiche attive.
  Future<void> cancelAllNotifications() async {
    await _notificationsPlugin.cancelAll();
  }
}
