import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:galaxy_alarm/models/alarm_model.dart';
import 'package:galaxy_alarm/services/alarm_service.dart';

class MockableAlarmService extends AlarmService {
  DateTime mockNow;

  MockableAlarmService(this.mockNow);

  // 현재 시간을 모킹하여 재활성화 날짜 계산에 사용
  @override
  DateTime getNow() {
    return mockNow;
  }

  // 다음 알람 시간 계산 오버라이드
  @override
  DateTime getNextAlarmDateTime(AlarmModel alarm) {
    // 현재 시간 대신 mockNow 사용
    final now = mockNow;

    // 기본 알람 시간 설정 (오늘)
    DateTime alarmDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      alarm.time.hour,
      alarm.time.minute,
    );

    // 이미 지난 시간이면 다음 날로 설정
    if (alarmDateTime.isBefore(now)) {
      alarmDateTime = alarmDateTime.add(const Duration(days: 1));
    }

    // 반복 알람이 아니면 그대로 반환
    if (!alarm.isRepeating) {
      return alarmDateTime;
    }

    // 요일 반복 알람일 경우
    final List<bool> repeatDays = alarm.weekdays;

    // 오늘 요일 (1:월요일, 7:일요일)
    final int todayWeekday = now.weekday % 7; // 0:일요일, 1:월요일, ..., 6:토요일

    // 반복 요일 확인
    bool isDaySelected = false;
    int daysToAdd = 0;

    // 최대 7일(일주일) 동안 반복
    for (int i = 0; i < 7; i++) {
      final int checkDay = (todayWeekday + i) % 7; // 확인할 요일

      // repeatDays의 인덱스는 0:월요일, 1:화요일, ..., 6:일요일
      // 우리 앱은 월요일이 0이지만 날짜 계산은 일요일이 0
      int repeatDayIndex = (checkDay + 6) % 7; // 요일 인덱스 변환

      if (repeatDays[repeatDayIndex]) {
        isDaySelected = true;
        daysToAdd = i;

        // 같은 날이지만 시간이 지났으면 다음 주기로
        if (i == 0 && alarmDateTime.isBefore(now)) {
          continue;
        }

        break;
      }
    }

    // 선택된 요일이 없으면 내일로 설정
    if (!isDaySelected) {
      return alarmDateTime.add(const Duration(days: 1));
    }

    return alarmDateTime.add(Duration(days: daysToAdd));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 테스트에 사용할 알람 데이터
  late AlarmModel testAlarm;

  setUp(() {
    // 테스트 전 SharedPreferences 초기화
    SharedPreferences.setMockInitialValues({});

    // 테스트용 알람 생성 (월-금 12시 알람)
    testAlarm = AlarmModel(
      id: 'test_alarm_1',
      time: const TimeOfDay(hour: 12, minute: 0),
      name: '테스트 알람',
      weekdays: [true, true, true, true, true, false, false], // 월-금
    );
  });

  group('AlarmService 자동 재활성화 테스트', () {
    test('알람 저장 및 불러오기 테스트', () async {
      final alarmService = AlarmService();

      // 알람 저장
      await alarmService.saveAlarm(testAlarm);

      // 알람 불러오기
      final alarms = await alarmService.getAlarms();

      expect(alarms.length, 1);
      expect(alarms[0].id, testAlarm.id);
      expect(alarms[0].time.hour, testAlarm.time.hour);
      expect(alarms[0].time.minute, testAlarm.time.minute);
      expect(alarms[0].weekdays, testAlarm.weekdays);
      expect(alarms[0].isActive, testAlarm.isActive);
    });

    test('알람 활성화/비활성화 테스트', () async {
      final alarmService = AlarmService();

      // 알람 저장
      await alarmService.saveAlarm(testAlarm);

      // 알람 비활성화
      await alarmService.toggleAlarmActive(testAlarm.id, false);

      // 알람 상태 확인
      final alarms = await alarmService.getAlarms();
      expect(alarms[0].isActive, false);
      expect(alarms[0].lastDisabledDate, isNotNull); // 비활성화 날짜가 저장됨

      // 알람 다시 활성화
      await alarmService.toggleAlarmActive(testAlarm.id, true);

      // 다시 알람 상태 확인
      final updatedAlarms = await alarmService.getAlarms();
      expect(updatedAlarms[0].isActive, true);
      expect(updatedAlarms[0].autoReenableDate, isNull); // 자동 재활성화 날짜가 초기화됨
    });

    test('알람 자동 재활성화 설정 테스트 - 수요일(12시 전)', () async {
      // 수요일 오전 11시로 설정 (알람 시간 전)
      final mockNow = DateTime(2023, 5, 24, 11, 0); // 수요일
      final mockService = MockableAlarmService(mockNow);

      // 알람 저장 및 비활성화
      await mockService.saveAlarm(testAlarm);
      await mockService.toggleAlarmActive(testAlarm.id, false);

      // 자동 재활성화 설정
      await mockService.setAutoReenableAlarm(testAlarm.id);

      // 알람 확인
      final alarms = await mockService.getAlarms();

      expect(alarms[0].autoReenableDate, isNotNull);
      // 오늘이 첫번째(수), 내일이 두번째(목) 알람이므로 목요일 자정에 재활성화
      final expected = DateTime(2023, 5, 25, 0, 0);
      expect(alarms[0].autoReenableDate, expected);
    });

    test('알람 자동 재활성화 설정 테스트 - 수요일(12시 후)', () async {
      // 수요일 오후 1시로 설정 (알람 시간 후)
      final mockNow = DateTime(2023, 5, 24, 13, 0); // 수요일
      final mockService = MockableAlarmService(mockNow);

      // 알람 저장 및 비활성화
      await mockService.saveAlarm(testAlarm);
      await mockService.toggleAlarmActive(testAlarm.id, false);

      // 자동 재활성화 설정
      await mockService.setAutoReenableAlarm(testAlarm.id);

      // 알람 확인
      final alarms = await mockService.getAlarms();

      expect(alarms[0].autoReenableDate, isNotNull);
      // 오늘 시간은 지났으므로, 내일(목)이 첫번째, 금요일이 두번째 알람
      // 따라서 금요일 자정에 재활성화
      final expected = DateTime(2023, 5, 26, 0, 0);
      expect(alarms[0].autoReenableDate, expected);
    });

    test('알람 자동 재활성화 취소 테스트', () async {
      final alarmService = AlarmService();

      // 알람 저장 및 비활성화
      await alarmService.saveAlarm(testAlarm);
      await alarmService.toggleAlarmActive(testAlarm.id, false);

      // 자동 재활성화 설정
      await alarmService.setAutoReenableAlarm(testAlarm.id);

      // 재활성화 취소
      await alarmService.cancelAutoReenableAlarm(testAlarm.id);

      // 알람 확인
      final alarms = await alarmService.getAlarms();
      expect(alarms[0].autoReenableDate, isNull);
      expect(alarms[0].isActive, false); // 여전히 비활성화 상태
    });

    test('알람 자동 재활성화 확인 테스트', () async {
      // 현재 시간을 5월 26일로 설정
      final mockNow = DateTime(2023, 5, 26, 10, 0);
      final mockService = MockableAlarmService(mockNow);

      // 알람 저장 및 비활성화
      await mockService.saveAlarm(testAlarm);
      await mockService.toggleAlarmActive(testAlarm.id, false);

      // 자동 재활성화 날짜를 5월 25일(이미 지난 날짜)로 설정
      await mockService.saveAlarm(testAlarm.copyWith(
        isActive: false,
        autoReenableDate: DateTime(2023, 5, 25, 0, 0),
      ));

      // 자동 재활성화 체크
      await mockService.checkAutoReenableAlarms();

      // 알람 확인 - 자동으로 다시 활성화되어야 함
      final alarms = await mockService.getAlarms();
      expect(alarms[0].isActive, true);
      expect(alarms[0].autoReenableDate, isNull);
      expect(alarms[0].lastDisabledDate, isNull);
    });

    test('공휴일에는 알람이 울리지 않는지 테스트', () async {
      // 2024년 1월 1일 (신정) 오전 10시로 설정
      final mockNow = DateTime(2024, 1, 1, 10, 0);
      final mockService = MockableAlarmService(mockNow);

      // 공휴일에는 끄기가 설정된 알람 생성
      final holidayAlarm = testAlarm.copyWith(
        skipHolidays: true,
        time: const TimeOfDay(hour: 12, minute: 0), // 정오 12시 알람
      );

      // 알람 저장
      await mockService.saveAlarm(holidayAlarm);
      // 다음 알람 시간 계산
      final nextAlarmTime = mockService.getNextAlarmDateTime(holidayAlarm);

      // 공휴일(1월 1일)을 건너뛰고 다음 평일(1월 2일)에 알람이 설정되어야 함
      final expected = DateTime(2024, 1, 2, 12, 0);
      expect(nextAlarmTime, expected);

      // 평일(1월 2일) 알람은 정상 작동
      final mockNextDay = DateTime(2024, 1, 2, 10, 0);
      final mockNextDayService = MockableAlarmService(mockNextDay);
      final nextDayAlarmTime =
          mockNextDayService.getNextAlarmDateTime(holidayAlarm);
      final expectedNextDay = DateTime(2024, 1, 2, 12, 0);
      expect(nextDayAlarmTime, expectedNextDay);
    });
  });
}
