import 'package:flutter/material.dart';

import 'history_screen.dart';
import 'home_screen.dart';
import 'medicines_screen.dart';
import 'schedule_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _i = 0;
  static const _items = [
    (Icons.dashboard_outlined, Icons.dashboard, 'Home'),
    (Icons.today_outlined, Icons.today, 'Schedule'),
    (Icons.medication_outlined, Icons.medication, 'Medicines'),
    (Icons.history, Icons.history, 'History'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];
  static const _pages = <Widget>[
    HomeScreen(), ScheduleScreen(), MedicinesScreen(), HistoryScreen(), SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 800;
    final body = IndexedStack(index: _i, children: _pages);
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _i,
            labelType: NavigationRailLabelType.all,
            onDestinationSelected: (v) => setState(() => _i = v),
            destinations: [
              for (final it in _items)
                NavigationRailDestination(
                    icon: Icon(it.$1), selectedIcon: Icon(it.$2), label: Text(it.$3)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ]),
      );
    }
    return Scaffold(
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _i,
        onDestinationSelected: (v) => setState(() => _i = v),
        destinations: [
          for (final it in _items)
            NavigationDestination(icon: Icon(it.$1), selectedIcon: Icon(it.$2), label: it.$3),
        ],
      ),
    );
  }
}
