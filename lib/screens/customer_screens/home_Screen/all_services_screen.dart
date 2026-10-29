import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';
import 'package:skill_link/design_system/widgets/skillnova_cards.dart';
import 'package:skill_link/design_system/widgets/skillnova_feedback.dart';
import 'package:skill_link/design_system/widgets/skillnova_inputs.dart';
import 'package:skill_link/design_system/widgets/skillnova_surfaces.dart';
import 'package:skill_link/models/service_data.dart';

/// Lets a customer pick a service category. Pops with the chosen title.
class AllServicesScreen extends StatefulWidget {
  const AllServicesScreen({super.key});

  @override
  State<AllServicesScreen> createState() => _AllServicesScreenState();
}

class _AllServicesScreenState extends State<AllServicesScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  List<ServiceOption> get _results {
    final query = _query.trim().toLowerCase();
    final results =
        allServices
            .where(
              (service) =>
                  query.isEmpty ||
                  service.title.toLowerCase().contains(query) ||
                  service.description.toLowerCase().contains(query),
            )
            .toList()
          ..sort((a, b) => a.title.compareTo(b.title));
    return results;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _clear() {
    _searchController.clear();
    setState(() => _query = '');
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final wide =
        MediaQuery.sizeOf(context).width >= SkillNovaBreakpoints.tablet;
    return Scaffold(
      appBar: AppBar(title: const Text('Choose a service')),
      body: SafeArea(
        top: false,
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: ContentWidth(
                maxWidth: 900,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    SkillNovaSpacing.gutter,
                    SkillNovaSpacing.xs,
                    SkillNovaSpacing.gutter,
                    SkillNovaSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pick what you need and we’ll take you straight to '
                        'your request.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      const SizedBox(height: SkillNovaSpacing.md),
                      SkillNovaSearchField(
                        controller: _searchController,
                        hintText: 'Search electrician, plumber, cleaner…',
                        onChanged: (value) => setState(() => _query = value),
                        trailing: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'Clear search',
                                onPressed: _clear,
                                icon: const Icon(Icons.close_rounded),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (results.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(SkillNovaSpacing.xl),
                    child: EmptyState(
                      icon: Icons.search_off_rounded,
                      title: 'No matching service',
                      message:
                          'Try a broader word like “repair” or “cleaning”.',
                      actionLabel: 'Clear search',
                      onAction: _clear,
                    ),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: ContentWidth(
                  maxWidth: 900,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SkillNovaSpacing.gutter,
                      0,
                      SkillNovaSpacing.gutter,
                      SkillNovaSpacing.xxxl,
                    ),
                    child: wide
                        ? _grid(results)
                        : ListGroup(
                            children: [
                              for (final service in results) _row(service),
                            ],
                          ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _row(ServiceOption service) => ListRow(
    key: ValueKey(service.title),
    icon: service.icon,
    tone: SkillNovaTone.info,
    title: service.title,
    subtitle: service.description,
    onTap: () => Navigator.pop(context, service.title),
  );

  Widget _grid(List<ServiceOption> results) => GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: results.length,
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 440,
      mainAxisExtent: 76,
      crossAxisSpacing: SkillNovaSpacing.sm,
      mainAxisSpacing: SkillNovaSpacing.sm,
    ),
    itemBuilder: (context, index) =>
        SkillNovaCard(padding: EdgeInsets.zero, child: _row(results[index])),
  );
}
