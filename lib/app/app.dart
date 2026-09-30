import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/services/app_startup_service.dart';
import '../features/pengaturan/presentation/controllers/pengaturan_settings_controller.dart';
import 'router/app_router.dart';
import 'theme/app_theme.dart';

class PujanggaPosApp extends ConsumerWidget {
  const PujanggaPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final startupState = ref.watch(appStartupProvider);
    ref.listen(appSettingsProvider, (_, _) {});

    return startupState.when(
      data: (state) {
        final router = buildAppRouter(
          hasBusinessProfile: state.hasBusinessProfile,
        );

        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          routerConfig: router,
        );
      },
      loading: () => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const _StartupLoadingPage(),
      ),
      error: (error, stackTrace) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: _StartupErrorPage(
          message: error.toString(),
          onRetry: () => ref.invalidate(appStartupProvider),
        ),
      ),
    );
  }
}

class _StartupLoadingPage extends StatelessWidget {
  const _StartupLoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Menyiapkan Pujangga POS...'),
          ],
        ),
      ),
    );
  }
}

class _StartupErrorPage extends StatelessWidget {
  const _StartupErrorPage({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_amber_rounded, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Inisialisasi aplikasi gagal',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: onRetry, child: const Text('Coba Lagi')),
            ],
          ),
        ),
      ),
    );
  }
}
