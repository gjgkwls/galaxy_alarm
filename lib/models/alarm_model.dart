import 'package:flutter/material.dart';

class AlarmModel {
  final String id;
  final TimeOfDay time;
  final String name;
  final List<bool> weekdays; // [월, 화, 수, 목, 금, 토, 일]
  final bool isActive;
  final bool skipHolidays;
  final bool snoozeEnabled;
  final String ringtone;
  final DateTime? lastDisabledDate;

  AlarmModel({
    required this.id,
    required this.time,
    this.name = '',
    required this.weekdays,
    this.isActive = true,
    this.skipHolidays = false,
    this.snoozeEnabled = true,
    this.ringtone = 'iphone-alarm.mp3',
    this.lastDisabledDate,
  });

  // 새 알람 생성을 위한 팩토리 메서드
  factory AlarmModel.create({
    required TimeOfDay time,
    String name = '',
    List<bool>? weekdays,
    bool skipHolidays = false,
    bool snoozeEnabled = true,
    String ringtone = 'iphone-alarm.mp3',
  }) {
    return AlarmModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      time: time,
      name: name,
      weekdays: weekdays ?? List.filled(7, false),
      skipHolidays: skipHolidays,
      snoozeEnabled: snoozeEnabled,
      ringtone: ringtone,
    );
  }

  // 알람 복사 메서드
  AlarmModel copyWith({
    String? id,
    TimeOfDay? time,
    String? name,
    List<bool>? weekdays,
    bool? isActive,
    bool? skipHolidays,
    bool? snoozeEnabled,
    String? ringtone,
    DateTime? lastDisabledDate,
  }) {
    return AlarmModel(
      id: id ?? this.id,
      time: time ?? this.time,
      name: name ?? this.name,
      weekdays: weekdays ?? List.from(this.weekdays),
      isActive: isActive ?? this.isActive,
      skipHolidays: skipHolidays ?? this.skipHolidays,
      snoozeEnabled: snoozeEnabled ?? this.snoozeEnabled,
      ringtone: ringtone ?? this.ringtone,
      lastDisabledDate: lastDisabledDate ?? this.lastDisabledDate,
    );
  }

  // JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'hour': time.hour,
      'minute': time.minute,
      'name': name,
      'weekdays': weekdays,
      'isActive': isActive,
      'skipHolidays': skipHolidays,
      'snoozeEnabled': snoozeEnabled,
      'ringtone': ringtone,
      'lastDisabledDate': lastDisabledDate?.toIso8601String(),
    };
  }

  // JSON에서 변환
  factory AlarmModel.fromJson(Map<String, dynamic> json) {
    return AlarmModel(
      id: json['id'],
      time: TimeOfDay(hour: json['hour'], minute: json['minute']),
      name: json['name'],
      weekdays: List<bool>.from(json['weekdays']),
      isActive: json['isActive'],
      skipHolidays: json['skipHolidays'],
      snoozeEnabled: json['snoozeEnabled'],
      ringtone: json['ringtone'],
      lastDisabledDate: json['lastDisabledDate'] != null
          ? DateTime.parse(json['lastDisabledDate'])
          : null,
    );
  }

  // 알람이 반복 알람인지 확인
  bool get isRepeating => weekdays.contains(true);

  // 요일 텍스트 가져오기
  String getWeekdaysText() {
    if (!isRepeating) return '한 번만';

    final days = ['월', '화', '수', '목', '금', '토', '일'];
    final selectedDays = <String>[];

    for (int i = 0; i < 7; i++) {
      if (weekdays[i]) selectedDays.add(days[i]);
    }

    if (selectedDays.length == 7) return '매일';
    if (selectedDays.length == 5 &&
        weekdays[0] &&
        weekdays[1] &&
        weekdays[2] &&
        weekdays[3] &&
        weekdays[4]) return '주중';
    if (selectedDays.length == 2 && weekdays[5] && weekdays[6]) return '주말';

    return selectedDays.join(', ');
  }

  // 다음 알람 날짜 계산
  DateTime? getNextAlarmDate() {
    if (!isActive) return null;

    final now = DateTime.now();
    final currentTimeOfDay = TimeOfDay.fromDateTime(now);

    // 반복 알람이 아닌 경우
    if (!isRepeating) {
      final today = DateTime(
        now.year,
        now.month,
        now.day,
        time.hour,
        time.minute,
      );
      return currentTimeOfDay.hour > time.hour ||
              (currentTimeOfDay.hour == time.hour &&
                  currentTimeOfDay.minute >= time.minute)
          ? today.add(const Duration(days: 1))
          : today;
    }

    // 반복 알람인 경우
    int daysToAdd = 0;
    int currentWeekday = now.weekday - 1; // 0: 월요일, 6: 일요일

    // 오늘이 선택된 요일이고 현재 시간이 알람 시간보다 이전인 경우
    if (weekdays[currentWeekday] &&
        (currentTimeOfDay.hour < time.hour ||
            (currentTimeOfDay.hour == time.hour &&
                currentTimeOfDay.minute < time.minute))) {
      daysToAdd = 0;
    } else {
      // 다음 선택된 요일 찾기
      int nextDay = (currentWeekday + 1) % 7;
      int count = 1;

      while (!weekdays[nextDay] && count < 7) {
        nextDay = (nextDay + 1) % 7;
        count++;
      }

      if (count < 7) {
        daysToAdd = nextDay > currentWeekday
            ? nextDay - currentWeekday
            : 7 - (currentWeekday - nextDay);
      } else {
        return null; // 선택된 요일이 없음
      }
    }

    final nextAlarmDate = DateTime(
      now.year,
      now.month,
      now.day + daysToAdd,
      time.hour,
      time.minute,
    );

    return nextAlarmDate;
  }
}
