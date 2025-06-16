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
    final now = DateTime.now();

    // 오늘 설정한 시간
    final today = DateTime(
        now.year, now.month, now.day, _selectedTime.hour, _selectedTime.minute);

    String message = '';

    // 반복 알람인지 확인
    final isRepeating = _selectedWeekdays.contains(true);

    if (!isRepeating) {
      // 반복 없는 일회성 알람인 경우
      DateTime nextAlarmTime = today;

      // 설정 시간이 현재 시간보다 이전이면 다음날로 설정
      if (today.isBefore(now)) {
        nextAlarmTime = today.add(const Duration(days: 1));
      }

      // 정확한 시간 차이 계산
      final differenceInMinutes = nextAlarmTime.difference(now).inMinutes;
      final hours = differenceInMinutes ~/ 60;
      final minutes = differenceInMinutes % 60 + 1;

      if (hours > 0) {
        message = '$hours시간 $minutes분 후에 알람이 울립니다';
      } else {
        message = '$minutes분 후에 알람이 울립니다';
      }
    } else {
      // 반복 알람인 경우
      // 오늘의 요일 인덱스 (0: 월요일, 1: 화요일, ..., 6: 일요일)
      final todayIndex = now.weekday - 1;

      // 오늘 요일이 선택되었고, 설정 시간이 현재 시간 이후인 경우
      if (_selectedWeekdays[todayIndex] && today.isAfter(now)) {
        final differenceInMinutes = today.difference(now).inMinutes;
        final hours = differenceInMinutes ~/ 60;
        final minutes = differenceInMinutes % 60 + 1;

        if (hours > 0) {
          message = '$hours시간 $minutes분 후에 알람이 울립니다';
        } else {
          message = '$minutes분 후에 알람이 울립니다';
        }
      } else {
        // 다음 알람이 울릴 요일 찾기
        int daysUntilNextAlarm = 0;
        bool foundNextDay = false;

        // 내일부터 시작해서 선택된 다음 요일 찾기
        for (int i = 1; i <= 7; i++) {
          final nextDayIndex = (todayIndex + i) % 7;
          if (_selectedWeekdays[nextDayIndex]) {
            daysUntilNextAlarm = i;
            foundNextDay = true;
            break;
          }
        }

        // 오늘 요일이 선택되었지만 현재 시간이 이미 지난 경우
        if (!foundNextDay && _selectedWeekdays[todayIndex]) {
          daysUntilNextAlarm = 7; // 일주일 후 같은 요일
        }

        final nextAlarmDate = now.add(Duration(days: daysUntilNextAlarm));
        final nextAlarmTime = DateTime(nextAlarmDate.year, nextAlarmDate.month,
            nextAlarmDate.day, _selectedTime.hour, _selectedTime.minute);

        // 다음 알람까지 24시간 이내인 경우 시간으로 표시
        final differenceInMinutes = nextAlarmTime.difference(now).inMinutes;
        if (differenceInMinutes < 24 * 60) {
          final hours = differenceInMinutes ~/ 60;
          final minutes = differenceInMinutes % 60 + 1;

          if (hours > 0) {
            message = '$hours시간 $minutes분 후에 알람이 울립니다';
          } else {
            message = '$minutes분 후에 알람이 울립니다';
          }
        } else {
          // 24시간 이상인 경우 날짜와 시간으로 표시
          final weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
          final weekday = weekdayLabels[nextAlarmTime.weekday - 1];
          final amPm = _selectedTime.hour < 12 ? '오전' : '오후';
          final hour = _selectedTime.hour < 12
              ? _selectedTime.hour
              : _selectedTime.hour - 12;

          message = '${nextAlarmTime.month}월 ${nextAlarmTime.day}일 $weekday요일 '
              '$amPm ${hour == 0 ? 12 : hour}시 '
              '${_selectedTime.minute.toString().padLeft(2, '0')}분에 알람이 울립니다';
        }
      }
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
}
