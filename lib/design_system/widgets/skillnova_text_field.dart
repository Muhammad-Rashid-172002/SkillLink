import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:skill_link/design_system/skillnova_tokens.dart';

/// Labelled form field used across every SkillNova form.
///
/// The label sits above the input (never disappears while typing), errors
/// appear below it, and password fields get an accessible visibility toggle.
class SkillNovaTextField extends StatefulWidget {
  const SkillNovaTextField({
    super.key,
    required this.label,
    this.controller,
    this.focusNode,
    this.hint,
    this.helper,
    this.prefixIcon,
    this.suffix,
    this.validator,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.textInputAction,
    this.autofillHints,
    this.inputFormatters,
    this.textCapitalization = TextCapitalization.none,
    this.obscure = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.maxLength,
    this.optional = false,
  });

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? helper;
  final IconData? prefixIcon;
  final Widget? suffix;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final List<TextInputFormatter>? inputFormatters;
  final TextCapitalization textCapitalization;
  final bool obscure;
  final bool enabled;
  final bool autofocus;
  final int maxLines;
  final int? minLines;
  final int? maxLength;
  final bool optional;

  @override
  State<SkillNovaTextField> createState() => _SkillNovaTextFieldState();
}

class _SkillNovaTextFieldState extends State<SkillNovaTextField> {
  late bool _hidden = widget.obscure;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Text(
              widget.label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
            if (widget.optional) ...[
              const SizedBox(width: SkillNovaSpacing.xxs),
              Text('(optional)', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
        const SizedBox(height: SkillNovaSpacing.xs),
        TextFormField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          enabled: widget.enabled,
          autofocus: widget.autofocus,
          obscureText: _hidden,
          enableSuggestions: !widget.obscure,
          autocorrect: !widget.obscure,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          autofillHints: widget.autofillHints,
          inputFormatters: widget.inputFormatters,
          textCapitalization: widget.textCapitalization,
          maxLines: widget.obscure ? 1 : widget.maxLines,
          minLines: widget.minLines,
          maxLength: widget.maxLength,
          validator: widget.validator,
          onChanged: widget.onChanged,
          onFieldSubmitted: widget.onSubmitted,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: theme.textTheme.bodyLarge,
          decoration: InputDecoration(
            hintText: widget.hint,
            helperText: widget.helper,
            helperMaxLines: 2,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, size: 20),
            suffixIcon: widget.obscure
                ? IconButton(
                    tooltip: _hidden ? 'Show password' : 'Hide password',
                    onPressed: () => setState(() => _hidden = !_hidden),
                    icon: Icon(
                      _hidden
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 20,
                    ),
                  )
                : widget.suffix,
          ),
        ),
      ],
    );
  }
}

/// The label shown above every SkillNova form control (text fields,
/// dropdowns, pickers) so all forms share one treatment.
class SkillNovaFieldLabel extends StatelessWidget {
  const SkillNovaFieldLabel(this.label, {super.key, this.optional = false});

  final String label;
  final bool optional;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: SkillNovaSpacing.xs),
      child: Row(
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
          if (optional) ...[
            const SizedBox(width: SkillNovaSpacing.xxs),
            Text('(optional)', style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
