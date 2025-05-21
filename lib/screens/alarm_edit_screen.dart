import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:audioplayers/audioplayers.dart';
import '../models/alarm_model.dart';

class AlarmEditScreen extends StatefulWidget {
  final AlarmModel? alarm; // 기존 알람 편집 시 전달받음

  const AlarmEditScreen({super.key, this.alarm});

  @override
  State<AlarmEditScreen> createState() => _AlarmEditScreenState();
}

class _AlarmEditScreenState extends State<AlarmEditScreen> {
  late TimeOfDay _selectedTime;
  late List<bool> _selectedWeekdays;
  late bool _skipHolidays;
  late bool _snoozeEnabled;
  late TextEditingController _nameController;

  // 기본 벨소리 설정
  final String _defaultRingtone = 'iphone-alarm.mp3';

  final List<String> _weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];

  // 색상 테마 정의
  final Color _primaryColor = const Color(0xFF9C27B0); // 보라색
  final Color _backgroundColor = Colors.black;
  final Color _cardColor = const Color(0xFF1E1E1E);
  final Color _textColor = Colors.white;
  final Color _secondaryTextColor = Colors.grey;

  @override
  void initState() {
    super.initState();

    // 기존 알람 편집인 경우 해당 값으로 초기화, 아니면 기본값 설정
    _selectedTime = widget.alarm?.time ?? TimeOfDay.now();
    _selectedWeekdays = widget.alarm?.weekdays ?? List.filled(7, false);
    _skipHolidays = widget.alarm?.skipHolidays ?? false;
    _snoozeEnabled = widget.alarm?.snoozeEnabled ?? true;
    _nameController = TextEditingController(text: widget.alarm?.name ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _isRepeating => _selectedWeekdays.contains(true);

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
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: _textColor),
          bodyMedium: TextStyle(color: _textColor),
          titleMedium: TextStyle(color: _textColor),
          titleSmall: TextStyle(color: _secondaryTextColor),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _cardColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: _primaryColor, width: 2),
          ),
          labelStyle: TextStyle(color: _secondaryTextColor),
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return _primaryColor;
            }
            return Colors.grey.shade400;
          }),
          trackColor: WidgetStateProperty.resolveWith<Color>((states) {
            if (states.contains(WidgetState.selected)) {
              return _primaryColor.withOpacity(0.5);
            }
            return Colors.grey.shade700;
          }),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.alarm == null ? '알람 추가' : '알람 편집'),
          actions: [
            TextButton(
              onPressed: _saveAlarm,
              child: Text(
                '저장',
                style: TextStyle(
                  color: _primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTimeSelector(),
              const SizedBox(height: 24),
              _buildWeekdaySelector(),
              const SizedBox(height: 16),
              if (_isRepeating) _buildHolidaysToggle(),
              _buildNameInput(),
              const SizedBox(height: 16),
              _buildSnoozeToggle(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSelector() {
    // 현재 선택된 시간으로 DateTime 생성
    final now = DateTime.now();
    final initialDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
          child: Text(
            '시간 선택',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
        ),
        Container(
          height: 180,
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: CupertinoTheme(
            data: CupertinoThemeData(
              brightness: Brightness.dark,
              primaryColor: _primaryColor,
              textTheme: CupertinoTextThemeData(
                dateTimePickerTextStyle: TextStyle(
                  color: _textColor,
                  fontSize: 22,
                ),
              ),
            ),
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              initialDateTime: initialDateTime,
              use24hFormat: false, // 오전/오후 구분 표시
              onDateTimeChanged: (DateTime dateTime) {
                setState(() {
                  _selectedTime = TimeOfDay(
                    hour: dateTime.hour,
                    minute: dateTime.minute,
                  );
                });
              },
              backgroundColor: Colors.transparent,
            ),
          ),
        ),
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 12.0),
            child: Text(
              _selectedTime.hour < 12 ? '오전' : '오후',
              style: TextStyle(
                fontSize: 14,
                color: _primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdaySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
          child: Text(
            '반복',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(7, (index) {
              return _buildWeekdayButton(index);
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildWeekdayButton(int index) {
    final isSelected = _selectedWeekdays[index];

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedWeekdays[index] = !_selectedWeekdays[index];
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isSelected ? _primaryColor : Colors.transparent,
          border: Border.all(
            color: isSelected ? _primaryColor : Colors.grey.shade600,
            width: 1.5,
          ),
        ),
        child: Center(
          child: Text(
            _weekdayLabels[index],
            style: TextStyle(
              color: isSelected ? _textColor : Colors.grey.shade400,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHolidaysToggle() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16.0),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        title: Text(
          '공휴일에는 끄기',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '공휴일에는 알람이 울리지 않습니다',
          style: TextStyle(
            color: _secondaryTextColor,
            fontSize: 13,
          ),
        ),
        value: _skipHolidays,
        onChanged: (value) {
          setState(() {
            _skipHolidays = value;
          });
        },
        activeColor: _primaryColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  Widget _buildNameInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 12.0),
          child: Text(
            '알람 이름',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: _textColor,
            ),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: _cardColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: TextField(
            controller: _nameController,
            style: TextStyle(color: _textColor),
            decoration: InputDecoration(
              hintText: '알람 이름 입력 (선택)',
              hintStyle: TextStyle(color: _secondaryTextColor),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 16.0,
              ),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSnoozeToggle() {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: SwitchListTile(
        title: Text(
          '다시 알림',
          style: TextStyle(
            color: _textColor,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          '알람 울림 후 5분 간격으로 반복',
          style: TextStyle(
            color: _secondaryTextColor,
            fontSize: 13,
          ),
        ),
        value: _snoozeEnabled,
        onChanged: (value) {
          setState(() {
            _snoozeEnabled = value;
          });
        },
        activeColor: _primaryColor,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  void _saveAlarm() {
    // 새 알람 생성 또는 기존 알람 수정
    final AlarmModel newAlarm = widget.alarm != null
        ? widget.alarm!.copyWith(
            time: _selectedTime,
            name: _nameController.text.trim(),
            weekdays: _selectedWeekdays,
            skipHolidays: _skipHolidays,
            snoozeEnabled: _snoozeEnabled,
            ringtone: _defaultRingtone,
          )
        : AlarmModel.create(
            time: _selectedTime,
            name: _nameController.text.trim(),
            weekdays: _selectedWeekdays,
            skipHolidays: _skipHolidays,
            snoozeEnabled: _snoozeEnabled,
            ringtone: _defaultRingtone,
          );

    // 다음 알람 시간까지 남은 시간 계산
    final realNow = DateTime.now();
    final now = DateTime(
        realNow.year, realNow.month, realNow.day, realNow.hour, realNow.minute);

    final today = DateTime(
        now.year, now.month, now.day, _selectedTime.hour, _selectedTime.minute);

    DateTime nextAlarmTime;

    String message = '';

    if (_selectedWeekdays.isEmpty) {
      // 반복 없는 일회성 알람인 경우
      nextAlarmTime =
          today.isAfter(now) ? today : today.add(const Duration(days: 1));

      final difference = nextAlarmTime.difference(now);
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;

      if (hours > 0) {
        message = '$hours시간 $minutes분 후에 알람이 울립니다';
      } else {
        message = '$minutes분 후에 알람이 울립니다';
      }
    } else {
      // 반복 알람인 경우

      // 다음 알람이 울릴 요일 찾기
      int currentWeekday = now.weekday;
      if (currentWeekday == 0) currentWeekday = 7; // 일요일인 경우 7로 변환
      int daysUntilNextAlarm = getDaysUntilNextAlarm(_selectedWeekdays);

      final nextAlarmTime = today.add(Duration(days: daysUntilNextAlarm));

      final weekday =
          ['월', '화', '수', '목', '금', '토', '일'][nextAlarmTime.weekday - 1];
      message = '알람이 ${nextAlarmTime.month}월 ${nextAlarmTime.day}일 $weekday요일 '
          '${nextAlarmTime.hour.toString().padLeft(2, '0')}시 '
          '${nextAlarmTime.minute.toString().padLeft(2, '0')}분에 설정되었어요.';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontSize: 14, color: Colors.white),
        ),
        backgroundColor: _cardColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    // 저장 후 화면 종료
    Navigator.pop(context, newAlarm);
  }

  int getDaysUntilNextAlarm(List<bool> selectedWeekdays) {
    if (selectedWeekdays.length != 7) {
      throw ArgumentError('selectedWeekdays는 7개의 항목을 가져야 합니다.');
    }

    final now = DateTime.now();
    final todayIndex = now.weekday - 1; // DateTime은 월=1 ~ 일=7 → index 0~6으로 맞춤

    for (int offset = 0; offset < 7; offset++) {
      int checkIndex = (todayIndex + offset) % 7;
      if (selectedWeekdays[checkIndex]) {
        return offset == 0 ? 7 : offset; // 오늘이면 일주일 뒤로 간주
      }
    }

    return -1; // 선택된 요일이 없을 경우
  }
}
