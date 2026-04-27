import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class Q1GoalsScreen extends StatefulWidget {
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;

  const Q1GoalsScreen({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<Q1GoalsScreen> createState() => _Q1GoalsScreenState();
}

class _Q1GoalsScreenState extends State<Q1GoalsScreen> {
  static const _options = [
    'Get more done in less time',
    'Improve work-life balance',
    'Organize tasks better',
    'Meet deadlines more reliably',
  ];

  void _toggle(String value) {
    final updated = List<String>.from(widget.selected);
    if (updated.contains(value)) {
      updated.remove(value);
    } else {
      if (updated.length < 2) {
        updated.add(value);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('You can select at most 2 goals'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primaryBlue,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }
    }
    widget.onChanged(updated);
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
              'Question 01',
              style: TextStyle(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'What are your main goals?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Select up to 2 options',
            style: TextStyle(fontSize: 14, color: AppColors.grayText),
          ),
          const SizedBox(height: 32),
          ..._options.map((option) {
            final isSelected = widget.selected.contains(option);
            return GestureDetector(
              onTap: () => _toggle(option),
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
                    Expanded(
                      child: Text(
                        option,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: isSelected ? Colors.white : AppColors.darkText,
                        ),
                      ),
                    ),
                    if (isSelected)
                      const Icon(Icons.check_circle,
                          color: Colors.white, size: 22),
                  ],
                ),
              ),
            );
          }),
          if (widget.selected.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Text(
                'Selected: ${widget.selected.length}/2',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryBlue,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
