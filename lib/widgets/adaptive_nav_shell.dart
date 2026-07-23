import 'package:flutter/material.dart';
import 'responsive_body.dart';

const double kWideBreakpoint = 700;

class NavDestination {
  final String label;
  final IconData icon;
  final WidgetBuilder contentBuilder;

  const NavDestination({
    required this.label,
    required this.icon,
    required this.contentBuilder,
  });
}

/// Standard Material 3 adaptive scaffold: a [NavigationRail] on wide/web
/// viewports, a bottom [NavigationBar] on narrow/mobile ones, so multi-screen
/// roles (branch staff, manager) switch destinations without push/back
/// navigation.
class AdaptiveNavShell extends StatefulWidget {
  final String subtitle;
  final List<NavDestination> destinations;
  final VoidCallback onSignOut;

  const AdaptiveNavShell({
    super.key,
    required this.subtitle,
    required this.destinations,
    required this.onSignOut,
  });

  @override
  State<AdaptiveNavShell> createState() => _AdaptiveNavShellState();
}

class _AdaptiveNavShellState extends State<AdaptiveNavShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final current = widget.destinations[_selectedIndex];
    final isWide = MediaQuery.sizeOf(context).width >= kWideBreakpoint;

    final appBar = AppBar(
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(current.label),
          Text(
            widget.subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).appBarTheme.foregroundColor?.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Sign out',
          onPressed: widget.onSignOut,
        ),
      ],
    );

    final body = ResponsiveBody(child: current.contentBuilder(context));

    if (isWide) {
      return Scaffold(
        appBar: appBar,
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (i) => setState(() => _selectedIndex = i),
              labelType: NavigationRailLabelType.all,
              destinations: widget.destinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: Icon(d.icon),
                      label: Text(d.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1),
            Expanded(child: body),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: appBar,
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (i) => setState(() => _selectedIndex = i),
        destinations: widget.destinations
            .map(
              (d) => NavigationDestination(icon: Icon(d.icon), label: d.label),
            )
            .toList(),
      ),
    );
  }
}
