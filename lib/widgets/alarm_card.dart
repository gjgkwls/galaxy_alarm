import 'package:flutter/material.dart';
import '../models/alarm_model.dart';
import 'package:intl/intl.dart';

class AlarmCard extends StatelessWidget {
  final AlarmModel alarm;
  final Function(bool) onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReactivate;
  final VoidCallback? onAutoReenableSet;
  final Color cardColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color accentColor;

  const AlarmCard({
    super.key,
    required this.alarm,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    required this.onReactivate,
    this.onAutoReenableSet,
    this.cardColor = const Color(0xFF1E1E1E),
    this.textColor = Colors.white,
    this.secondaryTextColor = Colors.grey,
    this.accentColor = const Color(0xFF9C27B0),
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12.0),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildTimeDisplay(),
                  const Spacer(),
                  if (alarm.skipHolidays)
                    Padding(
                      padding: const EdgeInsets.only(right: 12.0),
                      child: Text(
                        '공휴일에는 끄기',
                        style: TextStyle(
                          fontSize: 12,
                          color: secondaryTextColor,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  _buildSwitch(),
                ],
              ),
              if (alarm.name.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  alarm.name,
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryTextColor,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              _buildWeekdayRow(),
              _buildAutoReenableButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeDisplay() {
    final hour = alarm.time.hour;
    final minute = alarm.time.minute;
    final period = hour < 12 ? '오전' : '오후';
    final displayHour = hour % 12 == 0 ? 12 : hour % 12;

    return Row(
      children: [
        Text(
          '$displayHour:${minute.toString().padLeft(2, '0')}',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          period,
          style: TextStyle(
            fontSize: 14,
            color: secondaryTextColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSwitch() {
    return Transform.scale(
      scale: 0.8,
      child: Switch(
        value: alarm.isActive,
        onChanged: onToggle,
        activeColor: accentColor,
        activeTrackColor: accentColor.withOpacity(0.5),
        inactiveThumbColor: Colors.grey.shade400,
        inactiveTrackColor: Colors.grey.shade700,
      ),
    );
  }

  Widget _buildWeekdayRow() {
    final List<String> weekdayLabels = ['월', '화', '수', '목', '금', '토', '일'];
    final bool isRepeating = alarm.weekdays.contains(true);

    if (!isRepeating) {
      return Text(
        '반복 없음',
        style: TextStyle(
          fontSize: 12,
          color: secondaryTextColor,
        ),
      );
    }

    return Row(
      children: List.generate(7, (index) {
        final isSelected = alarm.weekdays[index];
        return Container(
          width: 24,
          height: 24,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isSelected ? accentColor : Colors.transparent,
          ),
          child: Center(
            child: Text(
              weekdayLabels[index],
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isSelected ? textColor : secondaryTextColor,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAutoReenableButton() {
    // 활성화된 알람이거나 반복 알람이 아니면 표시하지 않음
    if (alarm.isActive || !alarm.isRepeating || onAutoReenableSet == null) {
      return const SizedBox.shrink();
    }

    // 이미 자동 재활성화가 설정된 경우
    if (alarm.autoReenableDate != null) {
      final formatter = DateFormat('M월 d일에');
      final infoText = '${formatter.format(alarm.autoReenableDate!)} 알람이 울립니다';

      return Padding(
        padding: const EdgeInsets.only(top: 12.0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          child: Text(
            infoText,
            style: TextStyle(
              fontSize: 12,
              color: secondaryTextColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      );
    }

    // 자동 재활성화가 설정되지 않은 경우, 두 번째 미래 요일 계산해서 버튼 표시
    final nextReenableDate = alarm.getNextReenableDate();
    if (nextReenableDate == null) return const SizedBox.shrink();

    final month = nextReenableDate.month;
    final day = nextReenableDate.day;
    final buttonText = '$month월 $day일에 다시 켜기';

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: InkWell(
        onTap: onAutoReenableSet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            color: accentColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.schedule,
                size: 14,
                color: accentColor,
              ),
              const SizedBox(width: 4),
              Text(
                buttonText,
                style: TextStyle(
                  fontSize: 12,
                  color: accentColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
