import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alarm/alarm.dart';
import 'models/alarm_model.dart';
import 'screens/alarm_list_screen.dart';
import 'screens/alarm_ring_screen.dart';
import 'services/alarm_service.dart';
import 'services/notification_service.dart';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// 전역 RouteObserver 선언
final RouteObserver<PageRoute> routeObserver = RouteObserver<PageRoute>();

Future<void> main() async {
  // Flutter 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();

  // 세로 모드로 고정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // 시스템 UI 모드 설정 (상태바 표시)
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  // Alarm 패키지 초기화
  await Alarm.init();

  // 알림 권한 요청
  await _requestNotificationPermissions();

  // 앱 시작 시 모든 알람 재스케줄링
  final alarmService = AlarmService();
  await alarmService.rescheduleAllAlarms();

  // 자동 재활성화 알람 체크
  await alarmService.checkAutoReenableAlarms();

  // 앱 상태 변화 감지를 위한 옵저버 추가
  SystemChannels.lifecycle.setMessageHandler((msg) async {
    // 앱이 포그라운드로 돌아왔을 때 자동 재활성화 체크
    if (msg == AppLifecycleState.resumed.toString()) {
      await alarmService.checkAutoReenableAlarms();
    }
    return null;
  });

  runApp(const MyApp());
}

// 알림 권한 요청
Future<void> _requestNotificationPermissions() async {
  FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  if (Platform.isIOS) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
          critical: true,
        );
  } else if (Platform.isAndroid) {
    final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
        flutterLocalNotificationsPlugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    // Android 13 (API 33) 이상에서는 명시적 권한 요청 필요
    await androidImplementation?.requestNotificationsPermission();

    // 정확한 알람 권한 요청 (Android 12+)
    await androidImplementation?.requestExactAlarmsPermission();
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AlarmService _alarmService = AlarmService();
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();
  final GlobalKey<AlarmListScreenState> _alarmListKey =
      GlobalKey<AlarmListScreenState>();

  @override
  void initState() {
    super.initState();

    // 알람 패키지의 알람 이벤트 수신
    Alarm.ringing.listen((alarmSet) {
      for (final alarm in alarmSet.alarms) {
        _onAlarmRinging(alarm.id);
      }
    });

    // NotificationService 알람 이벤트 연결
    NotificationService.instance.onAlarmFired = (alarmId) {
      _onNotificationAlarmFired(alarmId);
    };

    // 앱 시작 시 이미 울리고 있는 알람이 있는지 확인
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // 현재 울리고 있는 알람이 있는지 확인
      final activeAlarms = await Alarm.getAlarms();
      if (activeAlarms.isNotEmpty) {
        // 알람 목록 가져오기
        final alarms = await _alarmService.getAlarms();

        // 각 알람 ID에 대해 확인
        for (final activeAlarm in activeAlarms) {
          try {
            // 울리고 있는 알람의 ID에 해당하는 알람 모델 찾기
            final alarm = alarms.firstWhere(
                (a) => a.id.hashCode.abs() % 1000000 == activeAlarm.id);

            // 알람 화면으로 이동
            _navigateToAlarmScreen(alarm);
            break; // 첫 번째 알람만 처리
          } catch (e) {
            debugPrint('알람 찾기 오류: $e');
          }
        }
      }

      // 앱이 알림을 통해 시작되었는지 확인
      final notificationAppLaunchDetails =
          await NotificationService.instance.getNotificationAppLaunchDetails();

      if (notificationAppLaunchDetails != null &&
          notificationAppLaunchDetails.didNotificationLaunchApp &&
          notificationAppLaunchDetails.notificationResponse?.payload != null) {
        final String alarmId =
            notificationAppLaunchDetails.notificationResponse!.payload!;
        _onNotificationAlarmFired(alarmId);
      }
    });
  }

  // 알람이 울렸을 때 실행될 콜백
  Future<void> _onAlarmRinging(int alarmId) async {
    try {
      // 알람 ID로 알람 정보 가져오기
      final alarms = await _alarmService.getAlarms();

      // int형 알람 ID를 문자열 ID로 변환해서 찾기
      final alarm = alarms
          .firstWhere((alarm) => alarm.id.hashCode.abs() % 1000000 == alarmId);

      // 알람 화면으로 이동
      _navigateToAlarmScreen(alarm);
    } catch (e) {
      debugPrint('알람 화면 이동 중 오류 발생: $e');
    }
  }

  // 알림을 통해 알람이 울렸을 때 실행될 콜백
  Future<void> _onNotificationAlarmFired(String alarmId) async {
    try {
      final alarms = await _alarmService.getAlarms();
      final alarm = alarms.firstWhere((alarm) => alarm.id == alarmId);

      // 알람 화면으로 이동
      _navigateToAlarmScreen(alarm);
    } catch (e) {
      debugPrint('알림 알람 화면 이동 중 오류 발생: $e');
    }
  }

  // 알람 화면으로 이동
  void _navigateToAlarmScreen(AlarmModel alarm) {
    // 전역 네비게이터 키를 통해 최상단 네비게이터에 접근
    _navigatorKey.currentState
        ?.push(
      MaterialPageRoute(
        builder: (context) => AlarmRingScreen(alarm: alarm),
      ),
    )
        .then((_) {
      // 알람 링 화면이 닫힐 때 알람 목록 화면의 상태를 갱신
      _alarmListKey.currentState?.refreshAlarms();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      navigatorObservers: [routeObserver],
      title: 'Galaxy Alarm',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      home: AlarmListScreen(key: _alarmListKey),
      debugShowCheckedModeBanner: false,
    );
  }
}
