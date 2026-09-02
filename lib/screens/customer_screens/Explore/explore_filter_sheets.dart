import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_buttons.dart';
import 'package:skill_link/models/service_data.dart';
import 'package:skill_link/screens/customer_screens/Explore/explore_models.dart';

Future<ExploreFilters?> showExploreFilterSheet({
  required BuildContext context,
  required ExploreFilters current,
  required bool distanceAvailable,
}) {
  return showModalBottomSheet<ExploreFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ExploreFilterSheet(
      current: current,
      distanceAvailable: distanceAvailable,
    ),
  );
}

Future<ExploreSort?> showExploreSortSheet({
  required BuildContext context,
  required ExploreSort current,
  required bool distanceAvailable,
}) {
  return showModalBottomSheet<ExploreSort>(
    context: context,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ExploreSortSheet(
      current: current,
      distanceAvailable: distanceAvailable,
    ),
  );
}

class _ExploreFilterSheet extends StatefulWidget {
  const _ExploreFilterSheet({
    required this.current,
    required this.distanceAvailable,
  });

  final ExploreFilters current;
  final bool distanceAvailable;

  @override
  State<_ExploreFilterSheet> createState() => _ExploreFilterSheetState();
}

class _ExploreFilterSheetState extends State<_ExploreFilterSheet> {
  late String _category;
  late double _minimumRating;
  late double? _maximumDistance;
  late final TextEditingController _minimumRate;
  late final TextEditingController _maximumRate;

  @override
  void initState() {
    super.initState();
    _category = widget.current.category;
    _minimumRating = widget.current.minimumRating;
    _maximumDistance = widget.distanceAvailable
        ? widget.current.maximumDistanceKm
        : null;
    _minimumRate = TextEditingController(
      text: widget.current.minimumRate?.toStringAsFixed(0) ?? '',
    );
    _maximumRate = TextEditingController(
      text: widget.current.maximumRate?.toStringAsFixed(0) ?? '',
    );
  }

  @override
  void dispose() {
    _minimumRate.dispose();
    _maximumRate.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      padding: EdgeInsets.fromLTRB(
        SkillNovaSpacing.lg,
        SkillNovaSpacing.sm,
        SkillNovaSpacing.lg,
        SkillNovaSpacing.lg + bottomInset,
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SkillNovaRadius.large),
        ),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            const SizedBox(height: SkillNovaSpacing.md),
            Text('Filters', style: theme.textTheme.headlineSmall),
            const SizedBox(height: SkillNovaSpacing.xxs),
            Text(
              'Only filters supported by current professional data are shown.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: SkillNovaSpacing.xl),
            Text('Service category', style: theme.textTheme.titleMedium),
            const SizedBox(height: SkillNovaSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _category,
              isExpanded: true,
              items: ['All', ...allServices.map((service) => service.title)]
                  .map(
                    (value) =>
                        DropdownMenuItem(value: value, child: Text(value)),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _category = value ?? 'All'),
            ),
            const SizedBox(height: SkillNovaSpacing.xl),
            Text('Minimum rating', style: theme.textTheme.titleMedium),
            const SizedBox(height: SkillNovaSpacing.sm),
            Wrap(
              spacing: SkillNovaSpacing.xs,
              runSpacing: SkillNovaSpacing.xs,
              children: const [0.0, 4.0, 4.5].map((rating) {
                return ChoiceChip(
                  selected: _minimumRating == rating,
                  label: Text(rating == 0 ? 'Any rating' : '$rating+ stars'),
                  onSelected: (_) => setState(() => _minimumRating = rating),
                );
              }).toList(),
            ),
            const SizedBox(height: SkillNovaSpacing.xl),
            Text('Hourly rate', style: theme.textTheme.titleMedium),
            const SizedBox(height: SkillNovaSpacing.sm),
            Row(
              children: [
                Expanded(child: _rateField(_minimumRate, 'Minimum')),
                const SizedBox(width: SkillNovaSpacing.sm),
                Expanded(child: _rateField(_maximumRate, 'Maximum')),
              ],
            ),
            const SizedBox(height: SkillNovaSpacing.xl),
            Container(
              padding: const EdgeInsets.all(SkillNovaSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(SkillNovaRadius.medium),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.verified_user_outlined,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: SkillNovaSpacing.sm),
                  Expanded(
                    child: Text(
                      'All Explore results are identity verified.',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            if (widget.distanceAvailable) ...[
              const SizedBox(height: SkillNovaSpacing.xl),
              Text('Maximum distance', style: theme.textTheme.titleMedium),
              const SizedBox(height: SkillNovaSpacing.sm),
              Wrap(
                spacing: SkillNovaSpacing.xs,
                runSpacing: SkillNovaSpacing.xs,
                children: <double?>[null, 5, 10, 25, 50].map((distance) {
                  return ChoiceChip(
                    selected: _maximumDistance == distance,
                    label: Text(
                      distance == null
                          ? 'Any distance'
                          : '${distance.toInt()} km',
                    ),
                    onSelected: (_) =>
                        setState(() => _maximumDistance = distance),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: SkillNovaSpacing.xl),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Reset',
                    onPressed: () {
                      Navigator.pop(context, const ExploreFilters());
                    },
                  ),
                ),
                const SizedBox(width: SkillNovaSpacing.sm),
                Expanded(
                  child: PrimaryButton(
                    label: 'Apply filters',
                    onPressed: _apply,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _rateField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))],
      decoration: InputDecoration(labelText: label, prefixText: 'Rs '),
    );
  }

  void _apply() {
    final minimum = double.tryParse(_minimumRate.text.trim());
    final maximum = double.tryParse(_maximumRate.text.trim());
    if (minimum != null && maximum != null && minimum > maximum) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Minimum rate cannot exceed maximum rate.'),
        ),
      );
      return;
    }
    Navigator.pop(
      context,
      ExploreFilters(
        category: _category,
        minimumRating: _minimumRating,
        minimumRate: minimum,
        maximumRate: maximum,
        maximumDistanceKm: widget.distanceAvailable ? _maximumDistance : null,
      ),
    );
  }
}

class _ExploreSortSheet extends StatelessWidget {
  const _ExploreSortSheet({
    required this.current,
    required this.distanceAvailable,
  });

  final ExploreSort current;
  final bool distanceAvailable;

  @override
  Widget build(BuildContext context) {
    final options = ExploreSort.values
        .where((option) => option != ExploreSort.nearest || distanceAvailable)
        .toList();
    return Container(
      padding: EdgeInsets.fromLTRB(
        SkillNovaSpacing.lg,
        SkillNovaSpacing.sm,
        SkillNovaSpacing.lg,
        SkillNovaSpacing.lg + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SkillNovaRadius.large),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),
          const SizedBox(height: SkillNovaSpacing.md),
          Text(
            'Sort professionals',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: SkillNovaSpacing.sm),
          ...options.map(
            (option) => ListTile(
              selected: option == current,
              contentPadding: EdgeInsets.zero,
              title: Text(option.label),
              trailing: option == current
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : const Icon(Icons.circle_outlined),
              onTap: () => Navigator.pop(context, option),
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 44,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.outlineVariant,
          borderRadius: BorderRadius.circular(SkillNovaRadius.pill),
        ),
      ),
    );
  }
}
