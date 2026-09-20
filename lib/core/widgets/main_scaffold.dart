// Persistent main navigation shell widget.
//
// Main Scaffold with clean bottom navigation and sync indicator.
// Provides shell layout for primary app destinations.:
// Home, Customers, Dashboard, and Settings.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../theme/color_tokens.dart';
import '../sync/sync_manager.dart';
import '../di/injection.dart';
import 'exit_dialog.dart';

class MainScaffold extends StatelessWidget {
  const MainScaffold({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // If not on the first tab (Home), navigate back to Home first
        if (navigationShell.currentIndex != 0) {
          navigationShell.goBranch(0);
          return;
        }

        // User is on Home tab, show Exit Dialog
        final shouldExit = await ExitDialog.show(context);
        if (shouldExit == true) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            // ── Top Sync Indicator (shown only when offline) ──────────────────
            const _TopSyncBanner(),

            // ── Active Tab Body ───────────────────────────────────────────────
            Expanded(child: navigationShell),
          ],
        ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark
              ? TarmeemColors.darkSurfaceContainer
              : TarmeemColors.surfaceContainerLowest,
          border: Border(
            top: BorderSide(
              color: isDark ? TarmeemColors.darkCardBorder : TarmeemColors.cardBorder,
              width: 1,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavBarItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'الرئيسية',
                  isSelected: navigationShell.currentIndex == 0,
                  onTap: () => _onTabSelected(0),
                ),
                _NavBarItem(
                  icon: Icons.people_alt_outlined,
                  activeIcon: Icons.people_alt_rounded,
                  label: 'العملاء',
                  isSelected: navigationShell.currentIndex == 1,
                  onTap: () => _onTabSelected(1),
                ),
                _NavBarItem(
                  icon: Icons.insights_outlined,
                  activeIcon: Icons.insights_rounded,
                  label: 'الداشبورد',
                  isSelected: navigationShell.currentIndex == 2,
                  onTap: () => _onTabSelected(2),
                ),
                _NavBarItem(
                  icon: Icons.settings_outlined,
                  activeIcon: Icons.settings_rounded,
                  label: 'الإعدادات',
                  isSelected: navigationShell.currentIndex == 3,
                  onTap: () => _onTabSelected(3),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

  void _onTabSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}

class _NavBarItem extends StatelessWidget {
  const _NavBarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? TarmeemColors.darkPrimary : TarmeemColors.primaryContainer;
    final inactiveColor = isDark ? TarmeemColors.darkOnSurfaceVariant : TarmeemColors.outline;
    final activeBg = isDark
        ? TarmeemColors.darkPrimaryContainer.withValues(alpha: 0.35)
        : TarmeemColors.primaryFixed.withValues(alpha: 0.6);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 24,
              color: isSelected ? activeColor : inactiveColor,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopSyncBanner extends StatelessWidget {
  const _TopSyncBanner();

  @override
  Widget build(BuildContext context) {
    final syncManager = getIt.isRegistered<SyncManager>()
        ? getIt<SyncManager>()
        : null;

    if (syncManager == null) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: Listenable.merge([
        syncManager.statusNotifier,
        syncManager.pendingCountNotifier,
      ]),
      builder: (context, _) {
        final syncStatus = syncManager.statusNotifier.value;
        final pendingCount = syncManager.pendingCountNotifier.value;
        final isOffline = syncStatus == SyncStatus.offline;

        if (!isOffline) {
          return const SizedBox.shrink();
        }

        return SafeArea(
          bottom: false,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: const BoxDecoration(
              color: Color(0xFFFEF3C7),
              border: Border(
                bottom: BorderSide(
                  color: TarmeemColors.cardBorder,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFD97706),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  pendingCount > 0
                      ? 'أوفلاين ($pendingCount معلق)'
                      : 'أوفلاين (حفظ محلي)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
