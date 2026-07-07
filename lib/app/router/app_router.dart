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
}

GoRouter buildAppRouter({required bool hasBusinessProfile}) {
  return GoRouter(
    initialLocation: hasBusinessProfile ? AppRoutes.home : AppRoutes.setup,
    routes: [
      GoRoute(
        path: AppRoutes.setup,
        builder: (context, state) => const SetupUsahaPage(),
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
                routes: [
                  GoRoute(
                    path: ':itemId',
                    builder: (context, state) {
                      final itemId = state.pathParameters['itemId'] ?? '-';
                      return DetailStokPage(itemId: itemId);
                    },
                  ),
                ],
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
        builder: (context, state) => const ItemFormPage(),
      ),
      GoRoute(
        path: '${AppRoutes.catalog}/edit/:id',
        builder: (context, state) {
          final itemId = state.pathParameters['id'] ?? '-';
          return ItemFormPage(itemId: itemId);
        },
      ),
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) => const RiwayatPage(),
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final transactionId = state.pathParameters['id'] ?? '-';
              return DetailTransaksiPage(transactionId: transactionId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '${AppRoutes.transactionSuccess}/:invoiceNumber',
        builder: (context, state) {
          final invoiceNumber = state.pathParameters['invoiceNumber'] ?? '-';
          return TransaksiBerhasilPage(invoiceNumber: invoiceNumber);
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const PengaturanPage(),
      ),
    ],
  );
}
