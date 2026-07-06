import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';

class MainNavigationShell extends StatelessWidget {
  const MainNavigationShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final destinations = const [
      NavigationDestination(
        icon: Icon(Icons.home_outlined),
        selectedIcon: Icon(Icons.home),
        label: 'Beranda',
      ),
      NavigationDestination(
        icon: Icon(Icons.inventory_2_outlined),
        selectedIcon: Icon(Icons.inventory_2),
        label: 'Katalog',
      ),
      NavigationDestination(
        icon: Icon(Icons.point_of_sale_outlined),
        selectedIcon: Icon(Icons.point_of_sale),
        label: 'Transaksi',
      ),
      NavigationDestination(
        icon: Icon(Icons.warehouse_outlined),
        selectedIcon: Icon(Icons.warehouse),
        label: 'Stok',
      ),
      NavigationDestination(
        icon: Icon(Icons.bar_chart_outlined),
        selectedIcon: Icon(Icons.bar_chart),
        label: 'Laporan',
      ),
    ];

    final titles = const [
      'Beranda',
      'Katalog',
      'Transaksi Baru',
      'Manajemen Stok',
      'Laporan',
    ];
    final currentIndex = navigationShell.currentIndex;

    return Scaffold(
      appBar: AppBar(
        title: Text(titles[currentIndex]),
        actions: [
          if (currentIndex == 0 || currentIndex == 2)
            IconButton(
              tooltip: 'Riwayat Transaksi',
              onPressed: () => context.push(AppRoutes.history),
              icon: const Icon(Icons.receipt_long_outlined),
            ),
          IconButton(
            tooltip: 'Pengaturan',
            onPressed: () => context.push(AppRoutes.settings),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        destinations: destinations,
        onDestinationSelected: (index) {
          navigationShell.goBranch(
            index,
            initialLocation: index == currentIndex,
          );
        },
      ),
    );
  }
}
