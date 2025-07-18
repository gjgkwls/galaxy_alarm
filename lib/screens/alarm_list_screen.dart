import 'package:flutter/material.dart';
import '../models/alarm_model.dart';
import '../services/alarm_service.dart';
import '../widgets/alarm_card.dart';
import 'alarm_edit_screen.dart';
import '../main.dart'; // RouteObserver import

class AlarmListScreen extends StatefulWidget {
  const AlarmListScreen({super.key});

  @override
  AlarmListScreenState createState() => AlarmListScreenState();
}

class AlarmListScreenState extends State<AlarmListScreen>
    with SingleTickerProviderStateMixin, RouteAware {
  final AlarmService _alarmService = AlarmService();
  List<AlarmModel> _alarms = [];
  bool _isLoading = true;

  // 색상 테마 정의
  final Color _primaryColor = const Color(0xFF9C27B0); // 보라색
  final Color _backgroundColor = Colors.black;
  final Color _cardColor = const Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _secondaryTextColor = Colors.grey;

  // 애니메이션 컨트롤러
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _loadAlarms();

    // 애니메이션 컨트롤러 초기화
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    routeObserver.subscribe(this, ModalRoute.of(context)! as PageRoute);
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _animationController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    super.didPopNext();
    // 다른 화면에서 돌아올 때 알람 목록 새로고침
    _loadAlarms();
  }

  // 외부에서 호출 가능한 상태 갱신 메서드
  void refreshAlarms() {
    _loadAlarms();
  }

  Future<void> _loadAlarms() async {
    setState(() {
      _isLoading = true;
    });

    final alarms = await _alarmService.getAlarms();

    setState(() {
      _alarms = alarms;
      _isLoading = false;
    });
  }

  Future<void> _toggleAlarm(String id, bool isActive) async {
    await _alarmService.toggleAlarmActive(id, isActive);
    await _loadAlarms();
  }

  Future<void> _deleteAlarm(String id) async {
    final oldAlarms = _alarms;
    final oldAlarmIndex = _alarms.indexWhere((a) => a.id == id);
    await _alarmService.deleteAlarm(id);
    await _loadAlarms();

    // 삭제 완료 후 스낵바 표시
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('알람이 삭제되었습니다'),
        backgroundColor: _cardColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        action: SnackBarAction(
          label: '실행 취소',
          textColor: _primaryColor,
          onPressed: () async {
            // 삭제된 알람을 임시 저장하고 복원
            final deletedAlarm = oldAlarms.firstWhere((a) => a.id == id);
            await _alarmService.saveAlarm(deletedAlarm, index: oldAlarmIndex);
            await _loadAlarms();
          },
        ),
      ),
    );
  }

  Future<void> _reactivateAlarm(AlarmModel alarm) async {
    await _alarmService.saveAlarm(
      alarm.copyWith(isActive: true, lastDisabledDate: null),
    );
    await _loadAlarms();
  }

  Future<void> _navigateToEditScreen(
    BuildContext context, [
    AlarmModel? alarm,
  ]) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlarmEditScreen(alarm: alarm),
      ),
    );

    if (result != null && result is AlarmModel) {
      await _alarmService.saveAlarm(result);
      await _loadAlarms();
    }
  }

  // 알람 자동 재활성화 설정
  Future<void> _setAutoReenableAlarm(String id) async {
    await _alarmService.setAutoReenableAlarm(id);

    // 설정 완료 후 알람 목록 새로고침
    await _loadAlarms();

    // 스낵바 표시
    final alarm = _alarms.firstWhere((a) => a.id == id);
    if (alarm.autoReenableDate != null) {
      final month = alarm.autoReenableDate!.month;
      final day = alarm.autoReenableDate!.day;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$month월 $day일에 알람이 자동으로 다시 켜집니다'),
          backgroundColor: _cardColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: _backgroundColor,
        colorScheme: ColorScheme.dark(
          primary: _primaryColor,
          secondary: _primaryColor,
          surface: _cardColor,
          onSurface: _textColor,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: _backgroundColor,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: _textColor,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: _primaryColor,
          foregroundColor: _textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('알람'),
        ),
        body: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                  color: _primaryColor,
                ),
              )
            : _buildAlarmList(),
        floatingActionButton: _buildAddButton(),
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: _primaryColor.withOpacity(0.3),
            blurRadius: 8,
            spreadRadius: 2,
          ),
        ],
      ),
      child: FloatingActionButton(
        onPressed: () => _navigateToEditScreen(context),
        elevation: 4,
        child: const Icon(Icons.add, size: 28),
      ),
    );
  }

  Widget _buildAlarmList() {
    return _alarms.isEmpty
        ? _buildEmptyState()
        : Column(
            children: [
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  itemCount: _alarms.length,
                  itemBuilder: (context, index) {
                    final alarm = _alarms[index];
                    return _buildAlarmItem(alarm, index);
                  },
                ),
              ),
            ],
          );
  }

  Widget _buildAlarmItem(AlarmModel alarm, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutQuad,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(0, 20 * (1 - value)),
          child: Opacity(
            opacity: value,
            child: Dismissible(
              key: Key(alarm.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20.0),
                decoration: BoxDecoration(
                  color: Colors.red.shade800,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              onDismissed: (direction) => _deleteAlarm(alarm.id),
              child: AlarmCard(
                alarm: alarm,
                onToggle: (isActive) => _toggleAlarm(alarm.id, isActive),
                onEdit: () => _navigateToEditScreen(context, alarm),
                onDelete: () => _deleteAlarm(alarm.id),
                onReactivate: () => _reactivateAlarm(alarm),
                onAutoReenableSet: alarm.isRepeating && !alarm.isActive
                    ? () => _setAutoReenableAlarm(alarm.id)
                    : null,
                cardColor: _cardColor,
                textColor: _textColor,
                secondaryTextColor: _secondaryTextColor,
                accentColor: _primaryColor,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.alarm_off,
            size: 80,
            color: _secondaryTextColor.withOpacity(0.7),
          ),
          const SizedBox(height: 24),
          Text(
            '알람이 없습니다',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '우측 하단의 + 버튼을 눌러 알람을 추가하세요',
            style: TextStyle(
              fontSize: 14,
              color: _secondaryTextColor,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => _navigateToEditScreen(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryColor,
              foregroundColor: _textColor,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '알람 추가하기',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
