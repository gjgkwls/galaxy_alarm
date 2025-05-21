import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import '../models/alarm_model.dart';

// 백그라운드에서도 알림 탭 핸들링 (top-level 함수로 정의)
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  // 백그라운드에서 알림 탭 처리
  // 앱이 종료된 상태에서도 알림을 탭하면 알람 화면으로 이동할 수 있도록
  final String? payload = notificationResponse.payload;
  if (payload != null) {
    debugPrint('백그라운드 알림: $payload');
    // 앱 시작 시 알람 화면으로 이동 로직은 main.dart에서 처리
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  static NotificationService get instance => _instance;

  late FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin;

  // 알람 ID를 알람 모델 ID와 매핑하는 맵
  final Map<String, int> _alarmNotificationIds = {};
  int _nextNotificationId = 0;

  // 알람이 울릴 때 내비게이터로 전체화면으로 이동하기 위한 콜백
  Function(String alarmId)? onAlarmFired;

  NotificationService._() {
    _init();
  }

  Future<void> _init() async {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    // 타임존 초기화
    tz_data.initializeTimeZones();

    // 알림 설정 초기화
    const androidInitSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS 설정 (iOS 10 이상)
    const DarwinInitializationSettings darwinInitSettings =
        DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
      defaultPresentSound: true,
      defaultPresentAlert: true,
    );

    const initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: darwinInitSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // 앱이 시작될 때 알림 권한 요청
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    if (Platform.isIOS) {
      await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidImplementation =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();

      await androidImplementation?.requestNotificationsPermission();
    }
  }

  // 알림 탭 처리
  void _onDidReceiveNotificationResponse(NotificationResponse response) {
    if (response.payload != null && onAlarmFired != null) {
      onAlarmFired!(response.payload!);
    }
  }

  // 알람 스케줄링
  Future<void> scheduleAlarm(AlarmModel alarm) async {
    // 알람이 비활성화된 경우 취소
    if (!alarm.isActive) {
      await cancelAlarm(alarm.id);
      return;
    }

    // 알람이 울릴 다음 날짜 계산
    final nextAlarmDate = alarm.getNextAlarmDate();
    if (nextAlarmDate == null) {
      return;
    }

    // 기존 알람이 있으면 취소
    await cancelAlarm(alarm.id);

    // 새 알람 ID 생성
    final notificationId = _getNotificationId(alarm.id);

    // 안드로이드용 알림 채널 생성 (중요도 향상)
    const String channelId = 'alarm_channel_high';
    const String channelName = '알람 (높은 중요도)';
    const String channelDescription = '알람 앱의 중요 알림 채널';

    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.max,
            sound: RawResourceAndroidNotificationSound(
                getAlarmSoundName(alarm.ringtone)),
            playSound: true,
            enableVibration: true,
            enableLights: true,
            showBadge: true,
          ),
        );

    // 알림 세부 정보 설정
    final androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound(
          getAlarmSoundName(alarm.ringtone)),
      enableLights: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      ongoing: true,
      visibility: NotificationVisibility.public,
      playSound: true,
      autoCancel: false,
      ticker: '알람',
      actions: [
        const AndroidNotificationAction(
          'stop',
          '중지',
          showsUserInterface: true,
          cancelNotification: true,
        ),
        const AndroidNotificationAction(
          'snooze',
          '다시 알림',
          showsUserInterface: true,
        ),
      ],
    );

    final iosDetails = DarwinNotificationDetails(
      sound: '${getAlarmSoundName(alarm.ringtone)}.mp3',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive, // 더 높은 중요도
      categoryIdentifier: 'alarm',
      threadIdentifier: 'alarm',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title = alarm.name.isNotEmpty ? '알람: ${alarm.name}' : '알람';

    final body =
        '${_formatTime(alarm.time)}${alarm.isRepeating ? ' - ${alarm.getWeekdaysText()}' : ''}';

    // 알람 스케줄링
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      title,
      body,
      tz.TZDateTime.from(nextAlarmDate, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: alarm.isRepeating
          ? DateTimeComponents.dayOfWeekAndTime
          : DateTimeComponents.time,
      payload: alarm.id,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('알람 스케줄링 완료: ${alarm.id} - ${nextAlarmDate.toString()}');
  }

  // 알람 스누즈
  Future<void> snoozeAlarm(AlarmModel alarm) async {
    // 스누즈가 비활성화된 경우
    if (!alarm.snoozeEnabled) {
      return;
    }

    final now = DateTime.now();
    final snoozeTime = now.add(const Duration(minutes: 5)); // 5분 후 재알림

    final notificationId = _getNotificationId(alarm.id);

    final androidDetails = AndroidNotificationDetails(
      'alarm_channel',
      '알람',
      channelDescription: '알람 알림 채널',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound(
          getAlarmSoundName(alarm.ringtone)),
      enableLights: true,
      enableVibration: true,
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      ongoing: true,
      visibility: NotificationVisibility.public,
      playSound: true,
    );

    final iosDetails = DarwinNotificationDetails(
      sound: '${getAlarmSoundName(alarm.ringtone)}.mp3',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      categoryIdentifier: 'alarm',
      threadIdentifier: 'alarm',
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    final title =
        alarm.name.isNotEmpty ? '알람 (다시 알림): ${alarm.name}' : '알람 (다시 알림)';

    final body = _formatTime(alarm.time);

    // 스누즈 알람 스케줄링
    await _flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      title,
      body,
      tz.TZDateTime.from(snoozeTime, tz.local),
      notificationDetails,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: alarm.id,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('스누즈 알람 스케줄링 완료: ${alarm.id} - ${snoozeTime.toString()}');
  }

  // 알람 취소
  Future<void> cancelAlarm(String alarmId) async {
    if (_alarmNotificationIds.containsKey(alarmId)) {
      final notificationId = _alarmNotificationIds[alarmId]!;
      await _flutterLocalNotificationsPlugin.cancel(notificationId);
    }
  }

  // 모든 알람 재스케줄링
  Future<void> rescheduleAllAlarms(List<AlarmModel> alarms) async {
    // 모든 알림 취소
    await _flutterLocalNotificationsPlugin.cancelAll();
    _alarmNotificationIds.clear();

    // 활성화된 알람만 다시 스케줄링
    for (final alarm in alarms) {
      if (alarm.isActive) {
        await scheduleAlarm(alarm);
      }
    }
  }

  // 알람 모델 ID에 해당하는 알림 ID 반환
  int _getNotificationId(String alarmId) {
    if (!_alarmNotificationIds.containsKey(alarmId)) {
      _alarmNotificationIds[alarmId] = _nextNotificationId++;
    }
    return _alarmNotificationIds[alarmId]!;
  }

  // 앱이 알림을 통해 시작되었는지 확인
  Future<NotificationAppLaunchDetails?>
      getNotificationAppLaunchDetails() async {
    return await _flutterLocalNotificationsPlugin
        .getNotificationAppLaunchDetails();
  }

  // 알람 벨소리 파일명 추출
  String getAlarmSoundName(String ringtonePath) {
    // ringtonePath는 'iphone-alarm.mp3' 형태
    // 확장자 제거하고 반환
    return ringtonePath.replaceAll(RegExp(r'\.mp3$'), '');
  }

  // 시간 포맷
  String _formatTime(TimeOfDay time) {
    final hour =
        time.hour == 0 ? 12 : (time.hour > 12 ? time.hour - 12 : time.hour);
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.hour < 12 ? '오전' : '오후';

    return '$period $hour:$minute';
  }
}
