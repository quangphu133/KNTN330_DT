import 'package:flutter/material.dart';

class SearchShell extends StatelessWidget {
  const SearchShell({
    super.key,
    required this.controller,
    required this.onChanged,
    this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.7),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.search_rounded, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Tìm kiếm cuộc gọi',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.zero,
                hintStyle: theme.textTheme.bodyMedium,
              ),
            ),
          ),
          AnimatedOpacity(
            duration: const Duration(milliseconds: 180),
            opacity: controller.text.isEmpty ? 0 : 1,
            child: IgnorePointer(
              ignoring: controller.text.isEmpty,
              child: IconButton(
                tooltip: 'Xóa nội dung tìm kiếm',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
