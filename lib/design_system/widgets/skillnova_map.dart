import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:url_launcher/url_launcher.dart';

import 'maps/maps_availability_stub.dart'
    if (dart.library.js_interop) 'maps/maps_availability_web.dart';

/// Builds a Google map only where the Maps SDK is actually available, and a
/// calm location card everywhere else (e.g. web builds without a Maps key),
/// instead of a red framework error.
class SkillNovaMap extends StatelessWidget {
  const SkillNovaMap({
    super.key,
    required this.builder,
    this.latitude,
    this.longitude,
    this.label,
  });

  final WidgetBuilder builder;
  final double? latitude;
  final double? longitude;

  /// Human-readable place shown in the fallback, e.g. "Hayatabad, Peshawar".
  final String? label;

  static bool get available => googleMapsLoaded();

  @override
  Widget build(BuildContext context) {
    if (available) return builder(context);
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final hasPoint = latitude != null && longitude != null;
    return Container(
      color: colors.surfaceContainer,
      padding: const EdgeInsets.all(SkillNovaSpacing.md),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.map_outlined, color: colors.onSurfaceVariant, size: 28),
          const SizedBox(height: SkillNovaSpacing.xs),
          Text(
            label?.trim().isNotEmpty == true ? label! : 'Map preview',
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.titleSmall,
          ),
          if (hasPoint) ...[
            const SizedBox(height: SkillNovaSpacing.xxs),
            TextButton.icon(
              onPressed: () => launchUrl(
                Uri.parse(
                  'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
                ),
                mode: LaunchMode.externalApplication,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('Open in Google Maps'),
            ),
          ],
        ],
      ),
    );
  }
}
