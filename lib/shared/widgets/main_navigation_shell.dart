import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router/app_router.dart';
import '../../core/services/app_startup_service.dart';

class MainNavigationShell extends ConsumerWidget {
  const MainNavigationShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final currentIndex = navigationShell.currentIndex;
 
    final profileAsync = ref.watch(businessProfileProvider);
    final logoPath = profileAsync.asData?.value?.logoPath;
 
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 48,
        backgroundColor: const Color(0xFFF8FAF8),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: 16,
        leadingWidth: 48,
        leading: IconButton(
          icon: const Icon(Icons.menu, color: Color(0xFF0D5C56)),
          onPressed: () {
            context.push(AppRoutes.settings);
          },
        ),
        title: const Text(
          'Pujangga-POS',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0D5C56),
          ),
        ),
        actions: [
          if (currentIndex == 0 || currentIndex == 2)
            IconButton(
              icon: const Icon(Icons.receipt_long_outlined, color: Color(0xFF0D5C56)),
              tooltip: 'Riwayat Transaksi',
              onPressed: () => context.push(AppRoutes.history),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Tooltip(
              message: 'Pengaturan',
              child: GestureDetector(
                onTap: () => context.push(AppRoutes.settings),
                child: (logoPath != null && logoPath.isNotEmpty && File(logoPath).existsSync())
                    ? Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFBEC9C6)),
                          image: DecorationImage(
                            image: FileImage(File(logoPath)),
                            fit: BoxFit.cover,
                          ),
                        ),
                      )
                    : Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFECEEED),
                          border: Border.all(color: const Color(0xFFBEC9C6)),
                        ),
                        child: const Icon(
                          Icons.storefront,
                          size: 18,
                          color: Color(0xFF3F4947),
                        ),
                      ),
              ),
            ),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(
            height: 1,
            thickness: 1,
            color: Color(0xFFBEC9C6),
          ),
        ),
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
