/// Status badge widget for displaying repair ticket status.
///
/// Matches the design spec exactly: pill shape, 28px height, leading dot,
/// with per-status color tokens from [TarmeemColors].
import 'package:flutter/material.dart';
import '../constants/app_constants.dart';
import '../theme/color_tokens.dart';

/// A pill-shaped status badge for a [TicketStatus].
class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  final TicketStatus status;

  /// When true, uses a smaller font and less padding.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = _colorsForStatus(status, isDark: isDark);
    return Container(
      height: compact ? 24 : 28,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: 0,
      ),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: colors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Leading status dot
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: colors.dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          // Status label
          Text(
            status.label,
            style: TextStyle(
              color: colors.text,
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w600,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }

  _StatusColors _colorsForStatus(TicketStatus status, {bool isDark = false}) {
    if (isDark) {
      switch (status) {
        case TicketStatus.inDiagnosis:
          return const _StatusColors(
            dot: TarmeemColors.darkDiagnosisDot,
            text: TarmeemColors.darkDiagnosisText,
            background: TarmeemColors.darkDiagnosisBackground,
            border: TarmeemColors.darkDiagnosisBorder,
          );
        case TicketStatus.waitingForPart:
          return const _StatusColors(
            dot: TarmeemColors.darkWaitingDot,
            text: TarmeemColors.darkWaitingText,
            background: TarmeemColors.darkWaitingBackground,
            border: TarmeemColors.darkWaitingBorder,
          );
        case TicketStatus.readyForPickup:
          return const _StatusColors(
            dot: TarmeemColors.darkReadyDot,
            text: TarmeemColors.darkReadyText,
            background: TarmeemColors.darkReadyBackground,
            border: TarmeemColors.darkReadyBorder,
          );
        case TicketStatus.delivered:
          return const _StatusColors(
            dot: TarmeemColors.darkDeliveredDot,
            text: TarmeemColors.darkDeliveredText,
            background: TarmeemColors.darkDeliveredBackground,
            border: TarmeemColors.darkDeliveredBorder,
          );
        case TicketStatus.cancelled:
          return _StatusColors(
            dot: const Color(0xFFF87171),
            text: const Color(0xFFFCA5A5),
            background: const Color(0xFF450A0A).withValues(alpha: 0.5),
            border: const Color(0xFF7F1D1D),
          );
      }
    }
    switch (status) {
      case TicketStatus.inDiagnosis:
        return const _StatusColors(
          dot: TarmeemColors.diagnosisDot,
          text: TarmeemColors.diagnosisText,
          background: TarmeemColors.diagnosisBackground,
          border: TarmeemColors.diagnosisBorder,
        );
      case TicketStatus.waitingForPart:
        return const _StatusColors(
          dot: TarmeemColors.waitingDot,
          text: TarmeemColors.waitingText,
          background: TarmeemColors.waitingBackground,
          border: TarmeemColors.waitingBorder,
        );
      case TicketStatus.readyForPickup:
        return const _StatusColors(
          dot: TarmeemColors.readyDot,
          text: TarmeemColors.readyText,
          background: TarmeemColors.readyBackground,
          border: TarmeemColors.readyBorder,
        );
      case TicketStatus.delivered:
        return const _StatusColors(
          dot: TarmeemColors.deliveredDot,
          text: TarmeemColors.deliveredText,
          background: TarmeemColors.deliveredBackground,
          border: TarmeemColors.deliveredBorder,
        );
      case TicketStatus.cancelled:
        return const _StatusColors(
          dot: Color(0xFFEF4444),
          text: Color(0xFFDC2626),
          background: Color(0xFFFEF2F2),
          border: Color(0xFFFECACA),
        );
    }
  }
}

class _StatusColors {
  final Color dot;
  final Color text;
  final Color background;
  final Color border;

  const _StatusColors({
    required this.dot,
    required this.text,
    required this.background,
    required this.border,
  });
}
