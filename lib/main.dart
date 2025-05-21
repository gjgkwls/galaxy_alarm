import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:alarm/alarm.dart';
import 'models/alarm_model.dart';
import 'screens/alarm_list_screen.dart';
import 'screens/alarm_ring_screen.dart';
import 'services/alarm_service.dart';

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

  // 앱 시작 시 모든 알람 재스케줄링
  final alarmService = AlarmService();
  await alarmService.rescheduleAllAlarms();

  // 스플래시 스크린 제거 (앱 로딩 완료)
  FlutterNativeSplash.remove();

  // 스플래시 스크린이 끝나면 상태바 다시 표시
  await SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  runApp(const MyApp());
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
