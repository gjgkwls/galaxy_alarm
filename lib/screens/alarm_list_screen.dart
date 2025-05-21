import 'package:flutter/material.dart';
import '../models/alarm_model.dart';
import '../services/alarm_service.dart';
import '../widgets/alarm_card.dart';
import 'alarm_edit_screen.dart';

class AlarmListScreen extends StatefulWidget {
  const AlarmListScreen({super.key});

  @override
  State<AlarmListScreen> createState() => _AlarmListScreenState();
}

class _AlarmListScreenState extends State<AlarmListScreen>
    with SingleTickerProviderStateMixin {
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
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
            await _alarmService.saveAlarm(deletedAlarm);
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
          actions: [
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                // 설정 화면으로 이동 (필요시 구현)
              },
            ),
          ],
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
              // 최근 비활성화된 반복 알람이 있는 경우 다시 켜기 버튼 표시
              _buildReactivateSection(),
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

  Widget _buildReactivateSection() {
    // 최근 비활성화된 반복 알람 찾기
    final recentDisabledAlarm = _alarms.where((alarm) {
      return alarm.isRepeating &&
          !alarm.isActive &&
          alarm.lastDisabledDate != null;
    }).toList();

    if (recentDisabledAlarm.isEmpty) {
      return const SizedBox.shrink();
    }

    // 가장 최근에 비활성화된 알람 선택
    recentDisabledAlarm.sort((a, b) => (b.lastDisabledDate ?? DateTime.now())
        .compareTo(a.lastDisabledDate ?? DateTime.now()));

    final alarm = recentDisabledAlarm.first;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16.0),
      child: ElevatedButton(
        onPressed: () => _reactivateAlarm(alarm),
        style: ElevatedButton.styleFrom(
          backgroundColor: _cardColor,
          foregroundColor: _primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          '다시 켜기 (${_formatDate(alarm.lastDisabledDate)})',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.month}월 ${date.day}일';
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
