// lib/shared/layouts/responsive_layout.dart
import 'package:flutter/material.dart';
import '../../core/constants/app_theme.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget body;
  final int selectedIndex;
  final List<NavigationItem> items;
  final void Function(int) onItemSelected;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const ResponsiveLayout({
    super.key,
    required this.body,
    required this.selectedIndex,
    required this.items,
    required this.onItemSelected,
    required this.title,
    this.actions,
    this.floatingActionButton,
  });

  static const double _breakpoint = 800;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width >= _breakpoint) {
      return _WebLayout(
        body: body,
        selectedIndex: selectedIndex,
        items: items,
        onItemSelected: onItemSelected,
        title: title,
        actions: actions,
        floatingActionButton: floatingActionButton,
      );
    }
    return _MobileLayout(
      body: body,
      selectedIndex: selectedIndex,
      items: items,
      onItemSelected: onItemSelected,
      title: title,
      actions: actions,
      floatingActionButton: floatingActionButton,
    );
  }
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  const NavigationItem({required this.icon, required this.activeIcon, required this.label});
}

// ── Web Sidebar Layout ───────────────────────────────────────
class _WebLayout extends StatelessWidget {
  final Widget body;
  final int selectedIndex;
  final List<NavigationItem> items;
  final void Function(int) onItemSelected;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const _WebLayout({
    required this.body,
    required this.selectedIndex,
    required this.items,
    required this.onItemSelected,
    required this.title,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 220,
            color: AppTheme.bgCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.adminPrimary, AppTheme.adminSecondary],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.home_work, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'SmartHostel',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Divider(height: 24),
                ...items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  final isSelected = i == selectedIndex;
                  return _SidebarItem(
                    icon: isSelected ? item.activeIcon : item.icon,
                    label: item.label,
                    isSelected: isSelected,
                    onTap: () => onItemSelected(i),
                  );
                }),
              ],
            ),
          ),
          // Content
          Expanded(
            child: Column(
              children: [
                Container(
                  color: AppTheme.bgCard,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Row(
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Spacer(),
                      if (actions != null) ...actions!,
                    ],
                  ),
                ),
                Expanded(child: body),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}

class _SidebarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.adminPrimary.withOpacity(0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? AppTheme.adminPrimary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppTheme.adminPrimary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mobile Bottom Nav Layout ─────────────────────────────────
class _MobileLayout extends StatelessWidget {
  final Widget body;
  final int selectedIndex;
  final List<NavigationItem> items;
  final void Function(int) onItemSelected;
  final String title;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const _MobileLayout({
    required this.body,
    required this.selectedIndex,
    required this.items,
    required this.onItemSelected,
    required this.title,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: Text(title),
        actions: actions,
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppTheme.bgCard,
        selectedIndex: selectedIndex,
        onDestinationSelected: onItemSelected,
        indicatorColor: AppTheme.adminPrimary.withOpacity(0.2),
        destinations: items
            .map((item) => NavigationDestination(
                  icon: Icon(item.icon, color: AppTheme.textSecondary),
                  selectedIcon: Icon(item.activeIcon, color: AppTheme.adminPrimary),
                  label: item.label,
                ))
            .toList(),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
