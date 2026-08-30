import 'package:flutter/material.dart';
import '../common/app_card.dart';

class SectionCard extends StatelessWidget {
  final List<Widget> children;
  final String? title;

  const SectionCard({
    super.key,
    required this.children,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // ✅ grab the current theme

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              title!,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: theme.textTheme.bodyLarge?.color, // ✅ theme-aware
              ),
            ),
          ),
        ],
        AppCard(
          padding: EdgeInsets.zero,
          child: Column(children: children),
        ),
      ],
    );
  }
}
