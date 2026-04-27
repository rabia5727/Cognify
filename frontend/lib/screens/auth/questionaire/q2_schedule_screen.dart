import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class Q2ScheduleScreen extends StatefulWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const Q2ScheduleScreen({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<Q2ScheduleScreen> createState() => _Q2ScheduleScreenState();
}

class _Q2ScheduleScreenState extends State<Q2ScheduleScreen> {
  static const _options = [
    'Fixed and Predictable',
    'Mostly predictable with some flexibility',
    'Unpredictable',
    'Completely in my control',
  ];

  void _select(String value) {
    if (widget.selected.contains(value)) {
      widget.onChanged([]);
    } else {
      widget.onChanged([value]);
    }
  }

  String _getDescription(String option) {
    switch (option) {
      case 'Fixed and Predictable':
        return 'same structure daily';
      case 'Unpredictable':
        return 'things change last minute';
      case 'Completely in my control':
        return 'I set my own hours';
      default:
        return '';
    }
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
              'Question 02',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'How would you describe your schedule?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select one option',
            style: TextStyle(fontSize: 14, color: AppColors.grayText),
          ),
          const SizedBox(height: 32),
          ..._options.map((option) {
            final isSelected = widget.selected.contains(option);
            final description = _getDescription(option);
            return GestureDetector(
              onTap: () => _select(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primaryBlue
                      : const Color(0xFFF5F7FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primaryBlue
                        : const Color(0xFFE0E7FF),
                    width: 1.5,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppColors.primaryBlue
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected ? Colors.white : AppColors.grayText,
                          width: 2,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              size: 14, color: Colors.white)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            option,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: isSelected
                                  ? Colors.white
                                  : AppColors.darkText,
                            ),
                          ),
                          if (description.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                description,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white70
                                      : AppColors.grayText,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
