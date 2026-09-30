import 'package:flutter/material.dart';

class SelectionOption<T> {
  const SelectionOption({
    required this.value,
    required this.label,
    this.caption,
    this.icon,
    this.color,
  });

  final T value;
  final String label;
  final String? caption;
  final IconData? icon;
  final Color? color;
}

class SelectionSheetField<T> extends StatelessWidget {
  const SelectionSheetField({
    super.key,
    required this.label,
    required this.sheetTitle,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.helperText,
    this.leadingIcon,
  });

  final String label;
  final String sheetTitle;
  final List<SelectionOption<T>> options;
  final T selectedValue;
  final ValueChanged<T> onSelected;
  final String? helperText;
  final IconData? leadingIcon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = options.firstWhere(
      (option) => option.value == selectedValue,
    );

    return Semantics(
      button: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () => _openSheet(context),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Row(
            children: [
              if (leadingIcon != null) ...[
                _LeadingPill(
                  icon: leadingIcon!,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 14),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (selected.color != null) ...[
                          _ColorDot(color: selected.color!),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(
                            selected.label,
                            style: theme.textTheme.titleMedium,
                          ),
                        ),
                      ],
                    ),
                    if (helperText != null) ...[
                      const SizedBox(height: 6),
                      Text(helperText!, style: theme.textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openSheet(BuildContext context) async {
    final theme = Theme.of(context);
    final result = await showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF7),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.shadow.withValues(alpha: 0.12),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sheetTitle, style: theme.textTheme.headlineMedium),
                  const SizedBox(height: 6),
                  Text(
                    'Choose one option to keep the task workflow focused.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 18),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 360),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: options.length,
                      separatorBuilder: (_, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final isSelected = option.value == selectedValue;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: () =>
                                Navigator.of(context).pop(option.value),
                            child: Ink(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? theme.colorScheme.primary.withValues(
                                        alpha: 0.09,
                                      )
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: isSelected
                                      ? theme.colorScheme.primary.withValues(
                                          alpha: 0.45,
                                        )
                                      : theme.colorScheme.outlineVariant
                                            .withValues(alpha: 0.6),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (option.icon != null ||
                                      option.color != null)
                                    _OptionBadge(
                                      icon: option.icon,
                                      color:
                                          option.color ??
                                          theme.colorScheme.primary,
                                    ),
                                  if (option.icon != null ||
                                      option.color != null)
                                    const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          option.label,
                                          style: theme.textTheme.titleMedium,
                                        ),
                                        if (option.caption != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            option.caption!,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme
                                                .colorScheme
                                                .surfaceContainerHighest,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Icon(
                                      isSelected
                                          ? Icons.check_rounded
                                          : Icons.add_rounded,
                                      size: 18,
                                      color: isSelected
                                          ? Colors.white
                                          : theme.colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );

    if (result != null) {
      onSelected(result);
    }
  }
}

class _LeadingPill extends StatelessWidget {
  const _LeadingPill({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

class _OptionBadge extends StatelessWidget {
  const _OptionBadge({this.icon, required this.color});

  final IconData? icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: icon != null
          ? Icon(icon, color: color)
          : Center(child: _ColorDot(color: color)),
    );
  }
}
