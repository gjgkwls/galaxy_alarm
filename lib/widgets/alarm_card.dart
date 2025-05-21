import 'package:flutter/material.dart';
import '../models/alarm_model.dart';

class AlarmCard extends StatelessWidget {
  final AlarmModel alarm;
  final Function(bool) onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onReactivate;
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTimeDisplay(),
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
}
