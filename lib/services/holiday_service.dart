import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HolidayService {
  static HolidayService _instance = HolidayService._();
  static HolidayService get instance => _instance;
  static set instance(HolidayService value) => _instance = value;

  SharedPreferences? _prefs;
  final String _apiKey =
      'ZnQJXSOFpMSI3TS5wjxTYy4x59q5VoIZNSktP5ruUjCTWCQ2wmfo5Sg8g3v335pzrptyokGO0n4wGew5E2wDbQ%3D%3D';
  final String _baseUrl =
      'http://apis.data.go.kr/B090041/openapi/service/SpcdeInfoService/getRestDeInfo';

  HolidayService._();

  // 캐시 키
  static const String _holidayCacheKey = 'holiday_cache';
  static const String _lastUpdateKey = 'holiday_last_update';

  // 캐시 만료 시간 (12시간)
  static const Duration _cacheExpiration = Duration(hours: 12);

  // 초기화 메서드
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  // 공휴일 체크 메서드
  Future<bool> isHoliday(DateTime date) async {
    try {
      // 주말 체크
      if (date.weekday == DateTime.saturday ||
          date.weekday == DateTime.sunday) {
        return true;
      }

      // 캐시된 공휴일 데이터 확인
      final cacheKey = '${date.year}_holidays';
      final cachedData = _prefs?.getString(cacheKey);

      if (cachedData != null) {
        final holidays = json.decode(cachedData) as List<dynamic>;
        return holidays.any((holiday) =>
            holiday['month'] == date.month && holiday['day'] == date.day);
      }

      // API 호출
      final queryParams = {
        'serviceKey': _apiKey,
        'solYear': date.year.toString(),
        '_type': 'json',
      };

      final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final items =
            data['response']['body']['items']['item'] as List<dynamic>;

        // 공휴일 데이터 캐시
        final holidays = items
            .map((item) {
              final locdate = item['locdate'].toString();
              return {
                'month': int.parse(locdate.substring(4, 6)),
                'day': int.parse(locdate.substring(6)),
                'isHoliday': item['isHoliday'] == 'Y',
              };
            })
            .where((holiday) => holiday['isHoliday'] == true)
            .toList();

        await _prefs?.setString(cacheKey, json.encode(holidays));

        // 현재 날짜가 공휴일인지 확인
        return holidays.any((holiday) =>
            holiday['month'] == date.month && holiday['day'] == date.day);
      }

      return false;
    } catch (e) {
      debugPrint('공휴일 체크 오류: $e');
      return false;
    }
  }
}
