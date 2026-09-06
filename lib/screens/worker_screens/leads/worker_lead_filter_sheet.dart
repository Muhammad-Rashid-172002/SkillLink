import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skill_link/screens/worker_screens/leads/worker_lead_models.dart';

Future<WorkerLeadFilters?> showWorkerLeadFilterSheet({
  required BuildContext context,
  required WorkerLeadFilters initial,
  required List<String> categories,
  required bool hasLocation,
}) {
  return showModalBottomSheet<WorkerLeadFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => WorkerLeadFilterSheet(
      initial: initial,
      categories: categories,
      hasLocation: hasLocation,
    ),
  );
}

Future<WorkerLeadSort?> showWorkerLeadSortSheet({
  required BuildContext context,
  required WorkerLeadSort selected,
  required bool hasDistance,
}) {
  final options = WorkerLeadSort.values
      .where((value) => hasDistance || value != WorkerLeadSort.nearest)
      .toList(growable: false);
  return showModalBottomSheet<WorkerLeadSort>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SheetHandle(),
          Text('Sort leads', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...options.map(
            (option) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(option.label),
              leading: Icon(_sortIcon(option)),
              trailing: option == selected
                  ? Icon(
                      Icons.check_circle_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : const Icon(Icons.circle_outlined),
              onTap: () => Navigator.pop(sheetContext, option),
            ),
          ),
        ],
      ),
    ),
  );
}

class WorkerLeadFilterSheet extends StatefulWidget {
  const WorkerLeadFilterSheet({
    super.key,
    required this.initial,
    required this.categories,
    required this.hasLocation,
  });

  final WorkerLeadFilters initial;
  final List<String> categories;
  final bool hasLocation;

  @override
  State<WorkerLeadFilterSheet> createState() => _WorkerLeadFilterSheetState();
}

class _WorkerLeadFilterSheetState extends State<WorkerLeadFilterSheet> {
  late String? _category;
  late String? _urgency;
  late double? _distance;
  late WorkerLeadPostedWithin _postedWithin;
  late final TextEditingController _minimumBudget;
  late final TextEditingController _maximumBudget;

  @override
  void initState() {
    super.initState();
    _category = widget.initial.category;
    _urgency = widget.initial.urgency;
    _distance = widget.hasLocation ? widget.initial.maximumDistanceKm : null;
    _postedWithin = widget.initial.postedWithin;
    _minimumBudget = TextEditingController(
      text: _numberText(widget.initial.minimumBudget),
    );
    _maximumBudget = TextEditingController(
      text: _numberText(widget.initial.maximumBudget),
    );
  }

  @override
  void dispose() {
    _minimumBudget.dispose();
    _maximumBudget.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SheetHandle(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Filter leads',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                TextButton(onPressed: _clear, child: const Text('Reset')),
              ],
            ),
            const SizedBox(height: 14),
            _label('Category'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('All matching'),
                  selected: _category == null,
                  onSelected: (_) => setState(() => _category = null),
                ),
                ...widget.categories.map(
                  (category) => ChoiceChip(
                    label: Text(category),
                    selected: _category == category,
                    onSelected: (_) => setState(() => _category = category),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _label('Urgency'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final value in const [
                  null,
                  'Normal',
                  'Urgent',
                  'Emergency',
                ])
                  ChoiceChip(
                    label: Text(value ?? 'Any'),
                    selected: _urgency == value,
                    onSelected: (_) => setState(() => _urgency = value),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            _label('Posted budget'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _budgetField(
                    key: const ValueKey('lead-min-budget'),
                    controller: _minimumBudget,
                    label: 'Minimum',
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _budgetField(
                    key: const ValueKey('lead-max-budget'),
                    controller: _maximumBudget,
                    label: 'Maximum',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _label('Posted time'),
            const SizedBox(height: 8),
            DropdownButtonFormField<WorkerLeadPostedWithin>(
              initialValue: _postedWithin,
              items: WorkerLeadPostedWithin.values
                  .map(
                    (value) => DropdownMenuItem(
                      value: value,
                      child: Text(value.label),
                    ),
                  )
                  .toList(growable: false),
              onChanged: (value) {
                if (value != null) setState(() => _postedWithin = value);
              },
            ),
            const SizedBox(height: 20),
            _label('Maximum distance'),
            const SizedBox(height: 8),
            if (!widget.hasLocation)
              Text(
                'Add a valid worker location to filter leads by distance.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final value in const [null, 5.0, 10.0, 25.0, 50.0])
                    ChoiceChip(
                      label: Text(
                        value == null ? 'Any' : '${value.toInt()} km',
                      ),
                      selected: _distance == value,
                      onSelected: (_) => setState(() => _distance = value),
                    ),
                ],
              ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                key: const ValueKey('apply-lead-filters'),
                onPressed: _apply,
                child: const Text('Apply filters'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text,
    style: Theme.of(
      context,
    ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
  );

  Widget _budgetField({
    required Key key,
    required TextEditingController controller,
    required String label,
  }) {
    return TextField(
      key: key,
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label, prefixText: 'Rs. '),
    );
  }

  void _clear() {
    setState(() {
      _category = null;
      _urgency = null;
      _distance = null;
      _postedWithin = WorkerLeadPostedWithin.any;
      _minimumBudget.clear();
      _maximumBudget.clear();
    });
  }

  void _apply() {
    final minimum = double.tryParse(_minimumBudget.text);
    final maximum = double.tryParse(_maximumBudget.text);
    Navigator.pop(
      context,
      WorkerLeadFilters(
        category: _category,
        urgency: _urgency,
        minimumBudget: minimum,
        maximumBudget: maximum,
        maximumDistanceKm: widget.hasLocation ? _distance : null,
        postedWithin: _postedWithin,
      ),
    );
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 42,
      height: 4,
      margin: const EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.outlineVariant,
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}

IconData _sortIcon(WorkerLeadSort sort) => switch (sort) {
  WorkerLeadSort.recommended => Icons.auto_awesome_outlined,
  WorkerLeadSort.newest => Icons.schedule_rounded,
  WorkerLeadSort.nearest => Icons.near_me_outlined,
  WorkerLeadSort.highestBudget => Icons.trending_up_rounded,
  WorkerLeadSort.lowestBudget => Icons.trending_down_rounded,
};

String _numberText(double? value) {
  if (value == null) return '';
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString();
}
