import 'package:flutter/material.dart';
import 'package:kiosk_core/kiosk_core.dart';

import '../session.dart';
import 'screens/dashboard_screen.dart';
import 'screens/kitchen_screen.dart';
import 'screens/menu_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/pickup_screen.dart';
import 'screens/settings_screen.dart';
import 'theme.dart';
import 'widgets/common.dart';

enum Section {
  dashboard('Riepilogo', Icons.insights_rounded),
  orders('Cassa', Icons.point_of_sale_rounded),
  kitchen('Cucina', Icons.soup_kitchen_rounded),
  pickup('Ritiro', Icons.tv_rounded),
  menu('Menu', Icons.restaurant_menu_rounded),
  settings('Impostazioni', Icons.tune_rounded);

  final String label;
  final IconData icon;
  const Section(this.label, this.icon);

  /// Kitchen and pickup screens only appear when the order flow uses them
  /// (e.g. not with "Solo ordine", where another system runs the kitchen).
  bool usedBy(FlowConfig flow) {
    bool uses(FlowAction a) => flow.rules.values.any((l) => l.contains(a));
    return switch (this) {
      Section.kitchen => uses(FlowAction.sendToKitchenDisplay),
      Section.pickup => uses(FlowAction.announceOnPickupScreen),
      _ => true,
    };
  }
}

/// Side navigation and the selected section. Kitchen and pickup screens
/// can go full screen for a dedicated monitor.
class StaffShell extends StatefulWidget {
  final VoidCallback onLogout;
  final Section initial;
  const StaffShell({
    super.key,
    required this.onLogout,
    this.initial = Section.orders,
  });

  @override
  State<StaffShell> createState() => _StaffShellState();
}

class _StaffShellState extends State<StaffShell> {
  late Section _section = widget.initial;
  bool _fullscreen = false;

  void _toggleFullscreen() => setState(() => _fullscreen = !_fullscreen);

  Widget _page(StaffSession session, Section section) => switch (section) {
    Section.dashboard => const DashboardScreen(),
    Section.orders => const OrdersScreen(),
    Section.kitchen => KitchenScreen(
      fullscreen: _fullscreen,
      onToggleFullscreen: _toggleFullscreen,
    ),
    Section.pickup => PickupScreen(
      api: session.api,
      onExit: _fullscreen ? _toggleFullscreen : null,
      onFullscreen: _fullscreen ? null : _toggleFullscreen,
    ),
    Section.menu => const MenuScreen(),
    Section.settings => const SettingsScreen(),
  };

  @override
  Widget build(BuildContext context) {
    final session = context.staff;
    final sections = [
      for (final s in Section.values)
        if (s.usedBy(session.settings.flow)) s,
    ];
    final section = sections.contains(_section) ? _section : Section.orders;
    final page = KeyedSubtree(
      key: ValueKey(section),
      child: _page(session, section),
    );
    if (_fullscreen) return Scaffold(body: page);
    return Scaffold(
      body: Row(
        children: [
          _Rail(
            sections: sections,
            selected: section,
            venue: session.settings.venueName,
            demo: session.settings.demoMode,
            onSelect: (s) => setState(() => _section = s),
            onLogout: () async {
              if (await confirm(
                context,
                title: 'Uscire dall\'area staff?',
                confirmLabel: 'Esci',
              )) {
                widget.onLogout();
              }
            },
          ),
          Expanded(
            child: AnimatedSwitcher(duration: S.medium, child: page),
          ),
        ],
      ),
    );
  }
}

class _Rail extends StatelessWidget {
  final List<Section> sections;
  final Section selected;
  final String venue;
  final bool demo;
  final ValueChanged<Section> onSelect;
  final VoidCallback onLogout;

  const _Rail({
    required this.sections,
    required this.selected,
    required this.venue,
    required this.demo,
    required this.onSelect,
    required this.onLogout,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      color: S.nav,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),
            ServerImage(
              '/media/placeholder/logo.svg',
              size: 56,
              radius: 28,
              recolor: true,
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                venue,
                maxLines: 2,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (demo) ...[
              const SizedBox(height: 6),
              Pill('DEMO', color: S.accent),
            ],
            const SizedBox(height: 14),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final s in sections)
                      _RailItem(
                        section: s,
                        selected: s == selected,
                        onTap: () => onSelect(s),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              key: const ValueKey('logout'),
              tooltip: 'Esci',
              onPressed: onLogout,
              icon: const Icon(Icons.logout_rounded, color: Colors.white54),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _RailItem extends StatelessWidget {
  final Section section;
  final bool selected;
  final VoidCallback onTap;
  const _RailItem({
    required this.section,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Material(
        color: selected ? S.navSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: ValueKey('nav-${section.name}'),
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(
                  section.icon,
                  color: selected ? S.onNavSelected : Colors.white60,
                  size: 26,
                ),
                const SizedBox(height: 4),
                Text(
                  section.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected ? S.onNavSelected : Colors.white60,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
