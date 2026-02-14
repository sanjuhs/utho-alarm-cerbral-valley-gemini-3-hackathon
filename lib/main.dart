import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'providers/alarm_provider.dart';
import 'providers/task_provider.dart';
import 'providers/preferences_provider.dart';
import 'services/alarm_service.dart';
import 'screens/home_screen.dart';
import 'utils/theme.dart';

/// Global navigator key for pushing routes from outside widget tree
/// (e.g. notification tap callbacks).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  // Request critical permissions before anything else (Android 13+)
  if (Platform.isAndroid) {
    await _requestPermissions();
  }

  // Init alarm notifications — pass navigator key for notification tap routing
  await AlarmScheduler.init(navigatorKey);

  runApp(const UthoApp());
}

/// Request notification + exact alarm + mic permissions up front.
/// Without these, alarms silently fail on Android 13+.
Future<void> _requestPermissions() async {
  // Notification permission (Android 13+ / API 33+)
  final notifStatus = await Permission.notification.status;
  if (!notifStatus.isGranted) {
    await Permission.notification.request();
  }

  // Exact alarm permission (Android 12+ / API 31+)
  final alarmStatus = await Permission.scheduleExactAlarm.status;
  if (!alarmStatus.isGranted) {
    await Permission.scheduleExactAlarm.request();
  }
}

class UthoApp extends StatelessWidget {
  const UthoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AlarmProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => PreferencesProvider()),
      ],
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'Utho!',
        debugShowCheckedModeBanner: false,
        theme: UthoTheme.dark,
        home: const HomeScreen(),
      ),
    );
  }
}
