import 'dart:isolate';
import 'dart:ui';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;
import '../models/alarm.dart';
import '../screens/alarm_ringing_screen.dart';
import '../services/database_service.dart';

/// Port name for communicating from alarm isolate → main isolate
const _alarmPortName = 'utho_alarm_port';

/// TOP-LEVEL callback — android_alarm_manager_plus requires this.
/// Runs in a background isolate when the alarm fires.
@pragma('vm:entry-point')
Future<void> uthoAlarmCallback(int alarmId) async {
  debugPrint('[Utho] ⏰ ALARM FIRED in background isolate! id=$alarmId');

  // Fire notification immediately from the background isolate
  final notifPlugin = FlutterLocalNotificationsPlugin();
  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  await notifPlugin.initialize(
    const InitializationSettings(android: androidSettings),
  );

  await notifPlugin.show(
    alarmId,
    'Utho! Wake up!',
    'Time to wake up!',
    const NotificationDetails(
      android: AndroidNotificationDetails(
        'utho_alarm_v3',
        'Utho Alarms',
        channelDescription: 'Alarm notifications',
        importance: Importance.max,
        priority: Priority.high,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        playSound: true,
        enableVibration: true,
        ongoing: true,
        autoCancel: false,
      ),
    ),
  );

  debugPrint('[Utho] ✓ Notification posted from background isolate');

  // Signal main isolate to open the ringing screen
  final sendPort = IsolateNameServer.lookupPortByName(_alarmPortName);
  sendPort?.send(alarmId);
}

class AlarmScheduler {
  static final _notifPlugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static GlobalKey<NavigatorState>? _navigatorKey;

  static Future<void> init(GlobalKey<NavigatorState> navigatorKey) async {
    if (_initialized) return;
    _navigatorKey = navigatorKey;

    // Timezone
    tz_data.initializeTimeZones();
    final deviceTzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(deviceTzInfo.identifier));
    debugPrint('[Utho] Device timezone: ${deviceTzInfo.identifier}');

    // Init android_alarm_manager_plus
    await AndroidAlarmManager.initialize();

    // Init flutter_local_notifications (for showing notifications, not scheduling)
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _notifPlugin.initialize(
      const InitializationSettings(android: androidSettings, iOS: iosSettings),
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Handle cold start from notification tap
    final launchDetails = await _notifPlugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchDetails!.notificationResponse != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _onNotificationTap(launchDetails.notificationResponse!);
      });
    }

    // Listen for alarm fires from the background isolate
    final receivePort = ReceivePort();
    IsolateNameServer.removePortNameMapping(_alarmPortName);
    IsolateNameServer.registerPortWithName(
        receivePort.sendPort, _alarmPortName);
    receivePort.listen((message) {
      if (message is int) {
        debugPrint(
            '[Utho] Main isolate received alarm fire for notifId=$message');
        _navigateToRingingScreen(message);
      }
    });

    _initialized = true;
  }

  static void _onNotificationTap(NotificationResponse response) async {
    _navigateToRingingScreen(response.id ?? 0);
  }

  static void _navigateToRingingScreen(int notifId) async {
    final nav = _navigatorKey?.currentState;
    if (nav == null) return;

    final alarms = await DatabaseService.getAlarms();
    Alarm? matched;
    for (final a in alarms) {
      if (a.id.hashCode == notifId) {
        matched = a;
        break;
      }
    }
    matched ??= Alarm(
      id: 'notif_$notifId',
      time: DateTime.now(),
      label: 'Alarm',
    );

    nav.push(MaterialPageRoute(
      builder: (_) => AlarmRingingScreen(alarm: matched!),
    ));
  }

  /// Schedule alarm using android_alarm_manager_plus
  static Future<void> schedule(Alarm alarm) async {
    if (!alarm.enabled) {
      await cancel(alarm);
      return;
    }

    final fireTime = alarm.nextFireTime;
    final now = DateTime.now();
    final alarmId = alarm.id.hashCode;
    final secondsUntil = fireTime.difference(now).inSeconds;

    debugPrint('[Utho] Scheduling alarm "${alarm.label}" id=$alarmId');
    debugPrint('[Utho]   fireTime: $fireTime');
    debugPrint('[Utho]   now: $now');
    debugPrint('[Utho]   fires in: ${secondsUntil}s');

    // Cancel any existing alarm with this id
    await AndroidAlarmManager.cancel(alarmId);

    // If fire time is in the past or within 3 seconds, fire immediately
    if (secondsUntil <= 3) {
      debugPrint('[Utho] Fire time is NOW or past — firing immediately');
      await uthoAlarmCallback(alarmId);
      return;
    }

    final success = await AndroidAlarmManager.oneShotAt(
      fireTime,
      alarmId,
      uthoAlarmCallback,
      exact: true,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
    );

    debugPrint(
        '[Utho] ${success ? '✓' : '✗'} AndroidAlarmManager.oneShotAt result: $success');
  }

  static Future<void> cancel(Alarm alarm) async {
    await AndroidAlarmManager.cancel(alarm.id.hashCode);
    await _notifPlugin.cancel(alarm.id.hashCode);
  }

  static Future<void> cancelAll() async {
    await _notifPlugin.cancelAll();
  }
}
