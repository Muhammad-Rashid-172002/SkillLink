import 'package:flutter/material.dart';
import 'package:skilllink_admin/theme/admin_design.dart';

/// Compact KPI tile: label, a large number and one line of context.
class DashboardStatCard extends StatelessWidget {
  const DashboardStatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.accent,
    required this.subtitle,
    this.onTap,
  });

  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Semantics(
      label: '$title: $value. $subtitle',
      button: onTap != null,
      excludeSemantics: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: kAdminBorder),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.labelLarge?.copyWith(
                          color: kAdminTextMuted,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(icon, color: accent, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  value,
                  style: text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: kAdminText,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.bodySmall?.copyWith(color: kAdminTextMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
