import 'package:flutter/material.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';

class SkillNovaSearchField extends StatelessWidget {
  const SkillNovaSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.onSubmitted,
    this.trailing,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final Widget? trailing;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return TextField(
      controller: controller,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      minLines: 1,
      maxLines: 2,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: Icon(Icons.search_rounded, color: colors.primary),
        suffixIcon: trailing,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SkillNovaSpacing.md,
          vertical: SkillNovaSpacing.md,
        ),
      ),
    );
  }
}
