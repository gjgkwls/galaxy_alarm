import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:alarm/alarm.dart';
import '../models/alarm_model.dart';
import '../services/alarm_service.dart';
import 'dart:async';

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
  final AlarmService _alarmService = AlarmService();
  bool _isSnoozing = false;
  bool _isStopping = false;

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
    _alarmId = widget.alarm.id.hashCode.abs() % 1000000;
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
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsed.dispose();
    _animationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
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
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // 앱이 다시 포그라운드로 돌아오면 설정 적용
    if (state == AppLifecycleState.resumed) {
      _configureForForeground();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _elapsed.value = Duration(seconds: timer.tick);
    });
  }

  Future<void> _snoozeAlarm() async {
    if (_isSnoozing) return;
    setState(() => _isSnoozing = true);

    try {
      // 현재 알람 중지
      await Alarm.stop(_alarmId);

      // 5분 후로 다시 알림 설정
      final now = DateTime.now();
      final snoozeTime = now.add(const Duration(minutes: 5));

      // 알람 설정 업데이트
      await _alarmService.saveAlarm(
        widget.alarm.copyWith(
          time: TimeOfDay.fromDateTime(snoozeTime),
          isActive: true,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('5분 후에 다시 알림이 울립니다.'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('다시 알림 설정 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('다시 알림 설정에 실패했습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSnoozing = false);
    }
  }

  Future<void> _stopAlarm() async {
    if (_isStopping) return;
    setState(() => _isStopping = true);

    try {
      // 알람 중지
      await Alarm.stop(_alarmId);

      if (widget.alarm.isRepeating) {
        // 반복 알람인 경우 다음 알람으로 업데이트
        await _alarmService.saveAlarm(widget.alarm);
      } else {
        // 일회성 알람인 경우 비활성화
        await _alarmService.saveAlarm(
          widget.alarm.copyWith(isActive: false),
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('알람 중지 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('알람 중지에 실패했습니다.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isStopping = false);
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour =
        time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String _getPeriod(TimeOfDay time) {
    return time.hour < 12 ? '오전' : '오후';
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
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
                              onPressed: _isSnoozing ? null : _snoozeAlarm,
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
                              onPressed: _isStopping ? null : _stopAlarm,
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
