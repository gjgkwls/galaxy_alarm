import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:alarm/alarm.dart';
import 'models/alarm_model.dart';
import 'screens/alarm_list_screen.dart';
import 'screens/alarm_ring_screen.dart';
import 'services/alarm_service.dart';
import 'services/notification_service.dart';
import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

Future<void> main() async {
  // 스플래시 스크린을 위한 바인딩 초기화
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  // 스플래시 스크린 유지
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // 상태바와 네비게이션바 숨기기 (전체 화면 모드)
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );

  // 앱이 화면 전체를 사용하도록 설정
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Alarm 패키지 초기화
  await Alarm.init();

  // 알림 권한 요청
  await _requestNotificationPermissions();

  // 앱 시작 시 모든 알람 재스케줄링
  final alarmService = AlarmService();
  await alarmService.rescheduleAllAlarms();

  // 자동 재활성화 알람 체크
  await alarmService.checkAutoReenableAlarms();

  // 스플래시 스크린 제거 (앱 로딩 완료)
  FlutterNativeSplash.remove();

  // 스플래시 스크린이 끝나면 상태바 다시 표시
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

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
    _navigatorKey.currentState?.push(
      MaterialPageRoute(
        builder: (context) => AlarmRingScreen(alarm: alarm),
        fullscreenDialog: true, // 전체 화면 다이얼로그로 표시
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
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
      home: const AlarmListScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
