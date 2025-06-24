import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alarm/alarm.dart';
import '../models/alarm_model.dart';
import '../services/alarm_service.dart';

class AlarmRingScreen extends StatefulWidget {
  final AlarmModel alarm;

  const AlarmRingScreen({
    super.key,
    required this.alarm,
  });

  @override
  State<AlarmRingScreen> createState() => _AlarmRingScreenState();
}

class _AlarmRingScreenState extends State<AlarmRingScreen>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final ValueNotifier<Duration> _elapsed =
      ValueNotifier<Duration>(Duration.zero);
  Timer? _timer;
  int _alarmId = 0;

  // 색상 테마 정의
  final Color _primaryColor = const Color(0xFFBB86FC); // 보라색 (다크 모드 최적화)
  final Color _backgroundColor = const Color(0xFF121212); // 더 어두운 배경색
  final Color _textColor = Colors.white;
  final Color _secondaryTextColor = const Color(0xFFBBBBBB); // 더 밝은 회색

  // 애니메이션 컨트롤러
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _alarmId = _generateAlarmId(widget.alarm.id);
    _startTimer();
    _configureForForeground();

    // 애니메이션 컨트롤러 초기화
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    // 알람 화면이 표시되면 시스템 알람이 이미 재생 중이므로
    // 추가로 소리를 재생할 필요는 없음
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsed.dispose();
    _animationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    // 앱의 일반 상태로 복원
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // 화면이 포그라운드에 표시되도록 설정
  void _configureForForeground() async {
    // 시스템 오버레이를 최소화하고 화면을 깨움
    await SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [], // 모든 오버레이 숨김
    );

    // 화면 방향 고정
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);

    // 화면 밝기 최대로 설정 (있을 경우)
    // 이 기능은 추가 패키지가 필요할 수 있음
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 앱이 다시 포그라운드로 돌아오면 설정 적용
    if (state == AppLifecycleState.resumed) {
      _configureForForeground();
    }
  }

  // 알람 ID를 int로 변환 (alarm 패키지는 int ID 사용)
  int _generateAlarmId(String id) {
    // 간단한 해시 함수로 문자열을 int로 변환
    return id.hashCode.abs() % 1000000;
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsed.value = Duration(seconds: timer.tick);
    });
  }

  void _dismissAlarm() async {
    // 알람 소리 중지
    await Alarm.stop(_alarmId);
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  void _snoozeAlarm() async {
    // 스누즈 기능이 활성화된 경우에만 스누즈
    if (widget.alarm.snoozeEnabled) {
      // 기존 알람 중지
      await Alarm.stop(_alarmId);

      // 5분 후로 스누즈 알람 설정
      final DateTime snoozeTime =
          DateTime.now().add(const Duration(minutes: 5));

      // 알람 설정
      final alarmSettings = AlarmSettings(
        id: _alarmId,
        dateTime: snoozeTime,
        assetAudioPath: 'assets/sounds/${widget.alarm.ringtone}',
        loopAudio: true,
        vibrate: true,
        androidFullScreenIntent: true,
        allowAlarmOverlap: true,
        androidStopAlarmOnTermination: false,
        volumeSettings: VolumeSettings.fade(
          volume: 1.0,
          fadeDuration: const Duration(seconds: 3),
          volumeEnforced: true,
        ),
        notificationSettings: NotificationSettings(
          title: '스누즈 알람',
          body: widget.alarm.name.isNotEmpty ? widget.alarm.name : '알람 시간입니다',
          stopButton: '중지',
        ),
      );

      await Alarm.set(alarmSettings: alarmSettings);
      debugPrint('스누즈 알람 설정: ${widget.alarm.id}, 시간: $snoozeTime');

      // 스누즈 설정 완료 메시지 표시
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '5분 후에 다시 알림이 울립니다',
            style: TextStyle(color: _textColor),
          ),
          backgroundColor: _backgroundColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    Navigator.of(context).pop();
  }

  String _formatTime(TimeOfDay time) {
    final hour =
        time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? '오전' : '오후';

    return '$hour:$minute';
  }

  String _getPeriod(TimeOfDay time) {
    return time.hour < 12 ? '오전' : '오후';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // 뒤로 가기 버튼으로 화면을 나갈 수 없게 함
        return false;
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _primaryColor.withOpacity(0.2),
                _backgroundColor,
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 1),

                  // 알람 아이콘 애니메이션
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: _primaryColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.alarm,
                            size: 60,
                            color: _primaryColor,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 40),

                  // 현재 시간 표시
                  ValueListenableBuilder(
                    valueListenable: _elapsed,
                    builder: (context, value, child) {
                      final now = TimeOfDay.now();
                      return Text(
                        '현재 시간 ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: _secondaryTextColor,
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 20),

                  // 알람 시간 표시
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        _formatTime(widget.alarm.time),
                        style: TextStyle(
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _getPeriod(widget.alarm.time),
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: _primaryColor,
                        ),
                      ),
                    ],
                  ),

                  // 알람 이름 표시
                  if (widget.alarm.name.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32.0,
                        vertical: 16.0,
                      ),
                      child: Text(
                        widget.alarm.name,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: _textColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  // 알람 주기 표시
                  if (widget.alarm.isRepeating)
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 16.0),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.alarm.getWeekdaysText(),
                        style: TextStyle(
                          fontSize: 16,
                          color: _primaryColor,
                        ),
                      ),
                    ),

                  const Spacer(flex: 1),

                  // 버튼 영역
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(24.0),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton(
                              onPressed: _snoozeAlarm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.black.withOpacity(0.5),
                                foregroundColor: _secondaryTextColor,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                '다시 알림',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: ElevatedButton(
                              onPressed: _dismissAlarm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _primaryColor,
                                foregroundColor: Colors.black,
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16.0),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.0),
                                ),
                                elevation: 4,
                              ),
                              child: const Text(
                                '끄기',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
