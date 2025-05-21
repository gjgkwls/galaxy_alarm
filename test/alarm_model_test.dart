import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:galaxy_alarm/models/alarm_model.dart';

// 테스트를 위한 확장 클래스
class TestableAlarmModel extends AlarmModel {
  final DateTime mockNow;

  TestableAlarmModel({
    required super.id,
    required super.time,
    required super.weekdays,
    required this.mockNow,
    super.name = '',
    super.isActive = true,
    super.skipHolidays = false,
    super.snoozeEnabled = true,
    super.ringtone = 'iphone-alarm.mp3',
    super.lastDisabledDate,
    super.autoReenableDate,
  });

  @override
  DateTime? getNextReenableDate() {
    // 활성화된 알람이거나 반복 알람이 아니면 null 반환
    if (isActive || !isRepeating) return null;

    final now = mockNow; // 모킹된 현재 시간 사용
    final currentTimeOfDay = TimeOfDay.fromDateTime(now);
    int currentWeekday = now.weekday - 1; // 0: 월요일, 6: 일요일

    // 앞으로의 요일 계산 (현재 요일부터 시작해서 반복 순환)
    List<int> futureDays = [];

    // 오늘이 반복 요일이고, 현재 시간이 알람 시간보다 이전인 경우 오늘도 포함
    bool includeToday = weekdays[currentWeekday] &&
        (currentTimeOfDay.hour < time.hour ||
            (currentTimeOfDay.hour == time.hour &&
                currentTimeOfDay.minute < time.minute));

    // 오늘부터 시작할지 내일부터 시작할지 결정
    int startDay = includeToday ? 0 : 1;

    // 앞으로 2주 동안의 반복 요일 계산
    for (int i = startDay; i <= 14; i++) {
      int checkDay = (currentWeekday + i) % 7;
      if (weekdays[checkDay]) {
        futureDays.add(i);
        if (futureDays.length == 2) break; // 두 개 찾으면 중단
      }
    }

    if (futureDays.isEmpty) return null;

    // 미래에 반복 요일이 1개만 있는 경우
    if (futureDays.length == 1) {
      return DateTime(
        now.year,
        now.month,
        now.day + futureDays[0],
      );
    }

    // 두 번째로 가까운 미래 요일 선택
    final secondFutureDay = futureDays[1];

    // 두 번째 미래 요일의 00:00:00 시간 반환
    return DateTime(
      now.year,
      now.month,
      now.day + secondFutureDay,
    );
  }

  @override
  bool isAutoReenableDatePassed() {
    if (autoReenableDate == null) return false;
    final now = mockNow; // 모킹된 현재 시간 사용
    final today = DateTime(now.year, now.month, now.day);
    final reenableDay = DateTime(
      autoReenableDate!.year,
      autoReenableDate!.month,
      autoReenableDate!.day,
    );
    return !reenableDay.isAfter(today); // 오늘이거나 과거인 경우 true
  }
}

void main() {
  group('AlarmModel 테스트', () {
    // 기본 생성 테스트
    test('AlarmModel 생성 테스트', () {
      const time = TimeOfDay(hour: 7, minute: 30);
      final weekdays = [true, true, true, true, true, false, false]; // 월-금

      final alarm = AlarmModel(
        id: '1',
        time: time,
        name: '출근 알람',
        weekdays: weekdays,
      );

      expect(alarm.id, '1');
      expect(alarm.time.hour, 7);
      expect(alarm.time.minute, 30);
      expect(alarm.name, '출근 알람');
      expect(alarm.weekdays, weekdays);
      expect(alarm.isActive, true);
      expect(alarm.isRepeating, true);
    });

    // 요일 텍스트 반환 테스트
    test('getWeekdaysText 테스트', () {
      final everyday = AlarmModel(
        id: '1',
        time: const TimeOfDay(hour: 7, minute: 0),
        weekdays: List.filled(7, true),
        name: '',
      );
      expect(everyday.getWeekdaysText(), '매일');

      final weekday = AlarmModel(
        id: '2',
        time: const TimeOfDay(hour: 7, minute: 0),
        weekdays: [true, true, true, true, true, false, false],
        name: '',
      );
      expect(weekday.getWeekdaysText(), '주중');

      final weekend = AlarmModel(
        id: '3',
        time: const TimeOfDay(hour: 9, minute: 0),
        weekdays: [false, false, false, false, false, true, true],
        name: '',
      );
      expect(weekend.getWeekdaysText(), '주말');

      final specific = AlarmModel(
        id: '4',
        time: const TimeOfDay(hour: 7, minute: 0),
        weekdays: [true, false, true, false, true, false, false],
        name: '',
      );
      expect(specific.getWeekdaysText(), '월, 수, 금');

      final noRepeat = AlarmModel(
        id: '5',
        time: const TimeOfDay(hour: 7, minute: 0),
        weekdays: List.filled(7, false),
        name: '',
      );
      expect(noRepeat.getWeekdaysText(), '한 번만');
    });

    // 다음 재활성화 날짜 계산 테스트
    group('getNextReenableDate 테스트', () {
      // 매일 반복되는 알람 (오늘 시간이 지나지 않은 경우)
      test('매일 반복 알람 - 오늘 시간 전', () {
        // 테스트용 시간 설정 - 5월 22일 오전 11시
        final mockNow = DateTime(2023, 5, 22, 11, 0);

        final alarm = TestableAlarmModel(
          id: '1',
          time: const TimeOfDay(hour: 12, minute: 0), // 정오 12시 알람
          weekdays: List.filled(7, true), // 매일 반복
          isActive: false, // 비활성화 상태
          mockNow: mockNow,
        );

        final nextReenableDate = alarm.getNextReenableDate();

        // 오늘이 첫번째, 내일이 두번째 미래 알람이므로 내일 자정이 재활성화 날짜
        final expected = DateTime(2023, 5, 23, 0, 0);
        expect(nextReenableDate, expected);
      });

      // 매일 반복되는 알람 (오늘 시간이 이미 지난 경우)
      test('매일 반복 알람 - 오늘 시간 후', () {
        // 테스트용 시간 설정 - 5월 22일 오후 1시
        final mockNow = DateTime(2023, 5, 22, 13, 0);

        final alarm = TestableAlarmModel(
          id: '1',
          time: const TimeOfDay(hour: 12, minute: 0), // 정오 12시 알람
          weekdays: List.filled(7, true), // 매일 반복
          isActive: false, // 비활성화 상태
          mockNow: mockNow,
        );

        final nextReenableDate = alarm.getNextReenableDate();

        // 오늘 시간은 지났으므로, 내일이 첫번째, 모레가 두번째 미래 알람
        // 따라서 모레(5월 24일) 자정이 재활성화 날짜
        final expected = DateTime(2023, 5, 24, 0, 0);
        expect(nextReenableDate, expected);
      });

      // 주중만 반복되는 알람 (수요일에 비활성화)
      test('주중 반복 알람 - 수요일에 비활성화', () {
        // 테스트용 시간 설정 - 5월 24일(수) 오전 11시
        final mockNow = DateTime(2023, 5, 24, 11, 0);

        final alarm = TestableAlarmModel(
          id: '1',
          time: const TimeOfDay(hour: 12, minute: 0), // 정오 12시 알람
          weekdays: [true, true, true, true, true, false, false], // 월-금
          isActive: false, // 비활성화 상태
          mockNow: mockNow,
        );

        final nextReenableDate = alarm.getNextReenableDate();

        // 오늘(수)은 아직 시간이 안 지남, 내일(목)이 두번째 미래 알람이므로
        // 재활성화 날짜는 내일(목요일) 자정
        final expected = DateTime(2023, 5, 25, 0, 0);
        expect(nextReenableDate, expected);
      });
    });

    // 자동 재활성화 날짜 지났는지 확인 테스트
    test('isAutoReenableDatePassed 테스트', () {
      // 재활성화 날짜 전
      final beforeAlarm = TestableAlarmModel(
        id: '1',
        time: const TimeOfDay(hour: 7, minute: 0),
        weekdays: List.filled(7, true),
        isActive: false,
        autoReenableDate: DateTime(2023, 5, 22),
        mockNow: DateTime(2023, 5, 21),
      );
      expect(beforeAlarm.isAutoReenableDatePassed(), false);

      // 재활성화 날짜와 같은 날
      final sameAlarm = TestableAlarmModel(
        id: '1',
        time: const TimeOfDay(hour: 7, minute: 0),
        weekdays: List.filled(7, true),
        isActive: false,
        autoReenableDate: DateTime(2023, 5, 22),
        mockNow: DateTime(2023, 5, 22, 12, 0),
      );
      expect(sameAlarm.isAutoReenableDatePassed(), true);

      // 재활성화 날짜 후
      final afterAlarm = TestableAlarmModel(
        id: '1',
        time: const TimeOfDay(hour: 7, minute: 0),
        weekdays: List.filled(7, true),
        isActive: false,
        autoReenableDate: DateTime(2023, 5, 22),
        mockNow: DateTime(2023, 5, 23),
      );
      expect(afterAlarm.isAutoReenableDatePassed(), true);
    });
  });
}
