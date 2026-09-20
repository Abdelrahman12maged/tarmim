/// Horizontally scrolling pill filter chip bar.
///
/// Used on the home screen to filter tickets by status.
/// Matches the design spec: selected pill uses primary fill, unselected uses outline.
import 'package:flutter/material.dart';
import '../theme/color_tokens.dart';

/// A horizontally scrollable row of filter chips.
class FilterChipBar extends StatelessWidget {
  const FilterChipBar({
    super.key,
    required this.options,
    required this.selectedIndex,
    required this.onSelected,
    this.counts,
  });

  /// List of label strings for each chip.
  final List<String> options;

  /// Index of the currently selected chip.
  final int selectedIndex;

  /// Callback when a chip is tapped.
  final void Function(int index) onSelected;

  /// Optional counts to display alongside each label.
  final List<int>? counts;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      reverse: true, // RTL: start scrolling from right
      child: Row(
        children: List.generate(options.length, (i) {
          // Reverse index because we reversed the scroll
          final index = options.length - 1 - i;
          final isSelected = selectedIndex == index;
          final count = counts != null ? counts![index] : null;

          return Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _FilterChip(
              label: options[index],
              count: count,
              isSelected: isSelected,
              onTap: () => onSelected(index),
            ),
          );
        }),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    this.count,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int? count;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer;
    final unselectedBg = isDark ? TarmeemColors.darkSurfaceContainer : TarmeemColors.surfaceContainerLowest;
    final selectedBorder = isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer;
    final unselectedBorder = isDark ? TarmeemColors.darkOutlineVariant : TarmeemColors.outlineVariant;
    final selectedText = isDark ? Colors.black : TarmeemColors.onPrimary;
    final unselectedText = isDark ? TarmeemColors.darkOnSurface : const Color(0xFF4B5563);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? selectedBg : unselectedBg,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(
            color: isSelected ? selectedBorder : unselectedBorder,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count != null) ...[
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: isSelected
                      ? (isDark ? Colors.black.withValues(alpha: 0.15) : TarmeemColors.onPrimary.withValues(alpha: 0.2))
                      : (isDark ? TarmeemColors.darkSurfaceContainerHigh : TarmeemColors.surfaceContainerHigh),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? selectedText
                          : (isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.onSurfaceVariant),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? selectedText : unselectedText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
