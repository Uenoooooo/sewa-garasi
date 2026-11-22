import 'package:flutter/material.dart';

import 'package:sewa_garasi/core/constants/app_colors.dart';

enum BadgeTone { success, warning, danger, info }

class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.label, required this.tone});

  final String label;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      BadgeTone.success => (AppColors.successLight, AppColors.success),
      BadgeTone.warning => (AppColors.warningLight, AppColors.warning),
      BadgeTone.danger => (AppColors.dangerLight, AppColors.danger),
      BadgeTone.info => (AppColors.infoLight, AppColors.info),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style:
                TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
