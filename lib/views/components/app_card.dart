import 'package:flutter/material.dart';

import 'package:sewa_garasi/core/constants/app_colors.dart';
import 'package:sewa_garasi/core/theme/app_theme.dart';

class LeadingBox extends StatelessWidget {
  const LeadingBox({
    super.key,
    this.icon,
    this.text,
    this.color = AppColors.primary,
    this.background = AppColors.primaryLight,
    this.size = 46,
  }) : assert(icon != null || text != null);

  final IconData? icon;
  final String? text;
  final Color color;
  final Color background;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: icon != null
          ? Icon(icon, color: color, size: size * 0.5)
          : Text(
              text!,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: size * 0.36,
              ),
            ),
    );
  }
}

class AppListCard extends StatelessWidget {
  const AppListCard({
    super.key,
    required this.leading,
    required this.title,
    this.lines = const [],
    this.trailing,
    this.footer,
    this.onTap,
  });

  final Widget leading;
  final String title;

  final List<String> lines;
  final Widget? trailing;

  final Widget? footer;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  leading,
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15),
                                ),
                              ),
                            ),
                            if (trailing != null) ...[
                              const SizedBox(width: 8),
                              trailing!,
                            ],
                          ],
                        ),
                        for (final line in lines) ...[
                          const SizedBox(height: 3),
                          Text(
                            line,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (onTap != null && trailing == null)
                    const Icon(Icons.chevron_right,
                        color: AppColors.textSecondary),
                ],
              ),
              if (footer != null) ...[
                const Divider(height: 22),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

enum NoticeTone { info, warning, success, neutral }

class NoticeCard extends StatelessWidget {
  const NoticeCard({
    super.key,
    required this.child,
    this.title,
    this.icon,
    this.tone = NoticeTone.info,
  });

  final String? title;
  final IconData? icon;
  final Widget child;
  final NoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      NoticeTone.info => (AppColors.primaryLight, AppColors.primary),
      NoticeTone.warning => (AppColors.warningLight, AppColors.warning),
      NoticeTone.success => (AppColors.successLight, AppColors.success),
      NoticeTone.neutral => (AppColors.surfaceMuted, AppColors.textSecondary),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: fg.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: fg),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(title!,
                      style: TextStyle(
                          color: fg,
                          fontWeight: FontWeight.w700,
                          fontSize: 14)),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          child,
        ],
      ),
    );
  }
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.step, this.subtitle});

  final String text;
  final int? step;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (step != null) ...[
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: Text('$step',
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: step != null ? 3 : 0),
                  child: Text(text,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 16)),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
