import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/beranda/presentation/pages/beranda_page.dart';
import '../../features/katalog/presentation/pages/item_form_page.dart';
import '../../features/katalog/presentation/pages/katalog_page.dart';
import '../../features/laporan/presentation/pages/laporan_page.dart';
import '../../features/pengaturan/presentation/pages/pengaturan_page.dart';
import '../../features/riwayat/presentation/pages/detail_transaksi_page.dart';
import '../../features/riwayat/presentation/pages/riwayat_page.dart';
import '../../features/setup_usaha/presentation/pages/setup_usaha_page.dart';
import '../../features/stok/presentation/pages/detail_stok_page.dart';
import '../../features/stok/presentation/pages/stok_page.dart';
import '../../features/transaksi/presentation/pages/transaksi_berhasil_page.dart';
import '../../features/transaksi/presentation/pages/transaksi_page.dart';
import '../../features/pengeluaran/presentation/pages/tambah_pengeluaran_page.dart';
import '../../shared/widgets/main_navigation_shell.dart';

class AppRoutes {
  static const setup = '/setup';
  static const home = '/home';
  static const catalog = '/catalog';
  static const catalogCreate = '/catalog/create';
  static const transaction = '/transaction';
  static const transactionSuccess = '/transaction/success';
  static const history = '/history';
  static const stock = '/stock';
  static const reports = '/reports';
  static const settings = '/settings';
  static const addExpense = '/add-expense';
}

GoRouter buildAppRouter({required bool hasBusinessProfile}) {
  return GoRouter(
    initialLocation: hasBusinessProfile ? AppRoutes.home : AppRoutes.setup,
    routes: [
      GoRoute(
        path: AppRoutes.setup,
        pageBuilder: (context, state) => buildPageWithTransition<void>(
          context: context,
          state: state,
          child: const SetupUsahaPage(),
          direction: SlideDirection.fadeOnly,
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainNavigationShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.home,
                builder: (context, state) => const BerandaPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.catalog,
                builder: (context, state) => const KatalogPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.transaction,
                builder: (context, state) => const TransaksiPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.stock,
                builder: (context, state) => const StokPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: AppRoutes.reports,
                builder: (context, state) => const LaporanPage(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.catalogCreate,
        pageBuilder: (context, state) => buildPageWithTransition<void>(
          context: context,
          state: state,
          child: const ItemFormPage(),
          direction: SlideDirection.rightToLeft,
        ),
      ),
      GoRoute(
        path: '${AppRoutes.catalog}/edit/:id',
        pageBuilder: (context, state) {
          final itemId = state.pathParameters['id'] ?? '-';
          return buildPageWithTransition<void>(
            context: context,
            state: state,
            child: ItemFormPage(itemId: itemId),
            direction: SlideDirection.rightToLeft,
          );
        },
      ),
      GoRoute(
        path: '${AppRoutes.stock}/:itemId',
        pageBuilder: (context, state) {
          final itemId = state.pathParameters['itemId'] ?? '-';
          return buildPageWithTransition<void>(
            context: context,
            state: state,
            child: DetailStokPage(itemId: itemId),
            direction: SlideDirection.rightToLeft,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.history,
        pageBuilder: (context, state) => buildPageWithTransition<void>(
          context: context,
          state: state,
          child: const RiwayatPage(),
          direction: SlideDirection.rightToLeft,
        ),
        routes: [
          GoRoute(
            path: ':id',
            pageBuilder: (context, state) {
              final transactionId = state.pathParameters['id'] ?? '-';
              return buildPageWithTransition<void>(
                context: context,
                state: state,
                child: DetailTransaksiPage(transactionId: transactionId),
                direction: SlideDirection.rightToLeft,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '${AppRoutes.transactionSuccess}/:invoiceNumber',
        pageBuilder: (context, state) {
          final invoiceNumber = state.pathParameters['invoiceNumber'] ?? '-';
          return buildPageWithTransition<void>(
            context: context,
            state: state,
            child: TransaksiBerhasilPage(invoiceNumber: invoiceNumber),
            direction: SlideDirection.bottomToTop,
          );
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        pageBuilder: (context, state) => buildPageWithTransition<void>(
          context: context,
          state: state,
          child: const PengaturanPage(),
          direction: SlideDirection.rightToLeft,
        ),
      ),
      GoRoute(
        path: AppRoutes.addExpense,
        pageBuilder: (context, state) => buildPageWithTransition<void>(
          context: context,
          state: state,
          child: const TambahPengeluaranPage(),
          direction: SlideDirection.bottomToTop,
        ),
      ),
    ],
  );
}

CustomTransitionPage<T> buildPageWithTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
  required SlideDirection direction,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 300),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      Offset begin;
      switch (direction) {
        case SlideDirection.rightToLeft:
          begin = const Offset(1.0, 0.0);
          break;
        case SlideDirection.bottomToTop:
          begin = const Offset(0.0, 1.0);
          break;
        case SlideDirection.fadeOnly:
          return FadeTransition(opacity: animation, child: child);
      }

      final tween = Tween(begin: begin, end: Offset.zero).chain(
        CurveTween(curve: Curves.easeInOutCubic),
      );

      return SlideTransition(
        position: animation.drive(tween),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}

enum SlideDirection {
  rightToLeft,
  bottomToTop,
  fadeOnly,
}
