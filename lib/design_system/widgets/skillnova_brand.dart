import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';

const String kSkillNovaLogoAsset = 'assets/app_icon_512x512(1).png';

/// The SkillNova "S" mark.
class SkillNovaLogo extends StatelessWidget {
  const SkillNovaLogo({super.key, this.size = 40, this.framed = false});

  final double size;

  /// Draws the mark on a soft rounded tile (for light backgrounds).
  final bool framed;

  @override
  Widget build(BuildContext context) {
    final mark = Image.asset(
      kSkillNovaLogoAsset,
      width: framed ? size * 0.72 : size,
      height: framed ? size * 0.72 : size,
      cacheWidth: (size * 3).round(),
      filterQuality: FilterQuality.medium,
      semanticLabel: 'SkillNova',
    );
    if (!framed) return mark;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(size * 0.3),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: SkillNovaElevation.subtle,
      ),
      child: mark,
    );
  }
}

/// Logo + name lockup.
class SkillNovaWordmark extends StatelessWidget {
  const SkillNovaWordmark({
    super.key,
    this.size = 32,
    this.color,
    this.tagline,
  });

  final double size;
  final Color? color;
  final String? tagline;

  @override
  Widget build(BuildContext context) {
    final textColor = color ?? Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SkillNovaLogo(size: size),
        SizedBox(width: size * 0.3),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SkillNova',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: textColor,
                fontSize: size * 0.62,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                height: 1.05,
              ),
            ),
            if (tagline != null)
              Text(
                tagline!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: size * 0.34,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
