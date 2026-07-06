import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pujangga_pos/app/app.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';

void main() {
  testWidgets('menampilkan setup usaha saat profil bisnis belum ada', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStartupProvider.overrideWith((ref) async {
            return const AppStartupState(hasBusinessProfile: false);
          }),
        ],
        child: const PujanggaPosApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Siapkan Bisnis'), findsOneWidget);
  });

  testWidgets('menampilkan beranda saat profil bisnis sudah ada', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStartupProvider.overrideWith((ref) async {
            return const AppStartupState(hasBusinessProfile: true);
          }),
        ],
        child: const PujanggaPosApp(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Beranda Pujangga POS'), findsOneWidget);
  });
}
