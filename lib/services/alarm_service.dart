import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import '../models/alarm_model.dart';

class AlarmService {
  static const String _alarmsKey = 'alarms';
  static const String _defaultRingtone = 'iphone-alarm.mp3';

  // 초기화 메서드
  Future<void> init() async {
    await Alarm.init();
  }

  // 모든 알람 가져오기
  Future<List<AlarmModel>> getAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    final alarmsJson = prefs.getStringList(_alarmsKey) ?? [];

    return alarmsJson
        .map((alarmJson) => AlarmModel.fromJson(jsonDecode(alarmJson)))
        .toList();
  }

  // 알람 저장하기
  Future<void> saveAlarm(AlarmModel alarm) async {
    final prefs = await SharedPreferences.getInstance();
    final alarms = await getAlarms();

    // 기존 알람 찾아서 대체하거나 새로운 알람 추가
    final existingIndex = alarms.indexWhere((a) => a.id == alarm.id);
    if (existingIndex >= 0) {
      alarms[existingIndex] = alarm;
    } else {
      alarms.add(alarm);
    }

    await _saveAlarms(alarms);

    // 알람을 스케줄링하거나 취소
    if (alarm.isActive) {
      await _scheduleAlarm(alarm);
    } else {
      await _cancelAlarm(alarm.id);
    }
  }

  // 알람 삭제하기
  Future<void> deleteAlarm(String id) async {
    final alarms = await getAlarms();
    alarms.removeWhere((alarm) => alarm.id == id);
    await _saveAlarms(alarms);

    // 알람 알림 취소
    await _cancelAlarm(id);
  }

  // 알람 활성화/비활성화
  Future<void> toggleAlarmActive(String id, bool isActive) async {
    final alarms = await getAlarms();
    final index = alarms.indexWhere((alarm) => alarm.id == id);

    if (index >= 0) {
      final alarm = alarms[index];
      final DateTime? lastDisabledDate = !isActive && alarm.isRepeating
          ? DateTime.now()
          : alarm.lastDisabledDate;

      alarms[index] = alarm.copyWith(
        isActive: isActive,
        lastDisabledDate: lastDisabledDate,
      );

      await _saveAlarms(alarms);

      // 알람 활성화/비활성화에 따라 알림 예약 또는 취소
      if (isActive) {
        await _scheduleAlarm(alarms[index]);
      } else {
        await _cancelAlarm(id);
      }
    }
  }

  // 알람 재활성화
  Future<void> reactivateAlarm(AlarmModel alarm) async {
    await saveAlarm(
      alarm.copyWith(isActive: true, lastDisabledDate: null),
    );
  }

  // 모든 알람 재스케줄링
  Future<void> rescheduleAllAlarms() async {
    final alarms = await getAlarms();

    // 모든 기존 알람 취소
    await Alarm.stopAll();

    // 활성화된 알람만 다시 스케줄링
    for (final alarm in alarms.where((a) => a.isActive)) {
      await _scheduleAlarm(alarm);
    }
  }

  // 다음 알람 날짜 형식으로 표시
  String formatNextAlarmDate(DateTime? date) {
    if (date == null) return '';

    return '${date.month}월 ${date.day}일';
  }

  // 모든 알람 저장 (내부 헬퍼 메서드)
  Future<void> _saveAlarms(List<AlarmModel> alarms) async {
    final prefs = await SharedPreferences.getInstance();
    final alarmsJson =
        alarms.map((alarm) => jsonEncode(alarm.toJson())).toList();

    await prefs.setStringList(_alarmsKey, alarmsJson);
  }

  // alarm 패키지를 사용하여 알람 스케줄링
  Future<void> _scheduleAlarm(AlarmModel alarm) async {
    try {
      // 알람 모델에서 다음 알람 시간 계산
      final DateTime nextAlarmDate = _getNextAlarmDateTime(alarm);

      // 고유 ID 생성 (문자열 id를 int로 변환)
      final int alarmId = _generateAlarmId(alarm.id);

      // 알람 설정
      final alarmSettings = AlarmSettings(
        id: alarmId,
        dateTime: nextAlarmDate,
        assetAudioPath: 'assets/sounds/${alarm.ringtone}',
        loopAudio: true,
        vibrate: true,
        androidFullScreenIntent: true,
        warningNotificationOnKill: Platform.isIOS,
        allowAlarmOverlap: true,
        androidStopAlarmOnTermination: false,
        volumeSettings: VolumeSettings.fade(
          volume: 1.0,
          fadeDuration: const Duration(seconds: 3),
          volumeEnforced: true,
        ),
        notificationSettings: NotificationSettings(
          title: '알람',
          body: alarm.name.isNotEmpty ? alarm.name : '알람 시간입니다',
          stopButton: '중지',
        ),
      );

      // 기존 알람 취소 후 새로 설정
      await Alarm.stop(alarmId);
      await Alarm.set(alarmSettings: alarmSettings);

      debugPrint('알람 설정됨: ${alarm.id}, 다음 시간: $nextAlarmDate');
    } catch (e) {
      debugPrint('알람 설정 오류: $e');
    }
  }

  // 알람 취소
  Future<void> _cancelAlarm(String id) async {
    try {
      await Alarm.stop(_generateAlarmId(id));
      debugPrint('알람 취소됨: $id');
    } catch (e) {
      debugPrint('알람 취소 오류: $e');
    }
  }

  // 알람 ID를 int로 변환 (alarm 패키지는 int ID 사용)
  int _generateAlarmId(String id) {
    // 간단한 해시 함수로 문자열을 int로 변환
    return id.hashCode.abs() % 1000000;
  }

  // 다음 알람 시간 계산
  DateTime _getNextAlarmDateTime(AlarmModel alarm) {
    final now = DateTime.now();

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
