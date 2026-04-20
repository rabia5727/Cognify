import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class Q3TaskloadScreen extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const Q3TaskloadScreen({
    super.key,
    required this.value,
    required this.onChanged,
  });

  String get _label {
    if (value <= 3) return 'Light';
    if (value <= 6) return 'Moderate';
    if (value <= 9) return 'Heavy';
    return 'Intense';
  }

  String get _displayValue {
    if (value >= 12) {
      return '12+';
    }
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F0FE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Question 03',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'How many tasks do you handle per day?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select your average',
            style: TextStyle(fontSize: 14, color: AppColors.grayText),
          ),
          const SizedBox(height: 32),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 32),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F7FF),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE0E7FF), width: 1.5),
            ),
            child: Column(
              children: [
                Text(
                  _displayValue,
                  style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value >= 12 ? 'tasks+ per day' : 'tasks per day',
                  style: const TextStyle(color: AppColors.grayText, fontSize: 14),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _label,
                    style: const TextStyle(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppColors.primaryBlue,
              inactiveTrackColor: const Color(0xFFE0E7FF),
              thumbColor: AppColors.primaryBlue,
              overlayColor: AppColors.primaryBlue.withOpacity(0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 14),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 26),
              trackHeight: 6,
            ),
            child: Slider(
              value: value.toDouble(),
              min: 1,
              max: 12,
              divisions: 11,
              onChanged: (v) => onChanged(v.round()),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1', style: TextStyle(color: AppColors.grayText)),
                Text('12+', style: TextStyle(color: AppColors.grayText)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}