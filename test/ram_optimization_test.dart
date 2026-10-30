import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/features/katalog/domain/entities/catalog_item.dart';
import 'package:pujangga_pos/features/katalog/presentation/controllers/katalog_controller.dart';
import 'package:pujangga_pos/features/katalog/presentation/models/katalog_state.dart';
import 'package:pujangga_pos/features/katalog/presentation/pages/katalog_page.dart';
import 'package:pujangga_pos/shared/widgets/catalog_thumbnail.dart';
import 'package:pujangga_pos/shared/widgets/scanner_session.dart';
import 'package:pujangga_pos/shared/widgets/business_logo.dart';
import 'package:pujangga_pos/features/setup_usaha/domain/entities/business_profile.dart';

class _CoffeeCatalog extends KatalogController {
  @override
  Future<KatalogState> build() async {
    final items = ['Arabica', 'Mesin Kopi', 'French Press'].indexed
        .map(
          (entry) => CatalogItem(
            id: '${entry.$1}',
            name: entry.$2,
            category: 'Kopi',
            itemType: 'barang',
            sellingPrice: 10000,
            isActive: true,
          ),
        )
        .toList();
    return KatalogState(allItems: items, filteredItems: items);
  }
}

class _Catalog extends KatalogController {
  @override
  Future<KatalogState> build() async {
    final items = List.generate(
      1000,
      (i) => CatalogItem(
        id: '$i',
        name: 'Produk $i',
        category: 'Kategori $i',
        itemType: 'barang',
        sellingPrice: 10000,
        isActive: true,
      ),
    );
    return KatalogState(allItems: items, filteredItems: items);
  }
}

void main() {
  testWidgets(
    'coffee names use the local business logo without network images',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            katalogControllerProvider.overrideWith(_CoffeeCatalog.new),
            businessProfileProvider.overrideWith(
              (ref) async => const BusinessProfile(
                businessName: 'Offline QA',
                businessType: 'retail',
                logoPath: 'missing-qa-logo.png',
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: KatalogPage())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(BusinessLogo), findsWidgets);
      for (final image in tester.widgetList<Image>(find.byType(Image))) {
        final provider = image.image as ResizeImage;
        expect(provider.imageProvider, isA<LocalLogoImage>());
        expect(image.fit, BoxFit.contain);
      }
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  test(
    'camera release waits for an in-flight start and survives errors',
    () async {
      final started = Completer<void>();
      final calls = <String>[];
      final session = ScannerSession(
        start: () async {
          calls.add('start');
          await started.future;
        },
        stop: () async {
          calls.add('stop');
          throw StateError('native failure');
        },
        dispose: () async {
          calls.add('dispose');
        },
      );
      unawaited(session.setActive(true));
      await Future<void>.delayed(Duration.zero);
      final closed = session.close();
      expect(calls, ['start']);
      started.complete();
      await closed;
      await session.setActive(true);
      expect(calls, ['start', 'stop', 'dispose']);
    },
  );

  test('camera pauses and resumes without overlapping native calls', () async {
    final calls = <String>[];
    final session = ScannerSession(
      start: () async {
        calls.add('start');
      },
      stop: () async {
        calls.add('stop');
      },
      dispose: () async {
        calls.add('dispose');
      },
    );
    await session.setActive(true);
    await session.setActive(false);
    await session.setActive(true);
    await session.close();
    expect(calls, ['start', 'stop', 'start', 'stop', 'dispose']);
  });

  testWidgets('thumbnail sizes decoding by density and shares cache keys', (
    tester,
  ) async {
    final source = MemoryImage(
      base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVQIHWP4z8DwHwAFgAI/ScLbtAAAAABJRU5ErkJggg==',
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 3),
          child: Center(
            child: SizedBox(
              width: 100,
              height: 80,
              child: Row(
                children: [
                  Expanded(child: CatalogThumbnail(image: source)),
                  Expanded(child: CatalogThumbnail(image: source)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    final images = tester.widgetList<Image>(find.byType(Image)).toList();
    final first = images.first.image as ResizeImage;
    expect(first.width, 256);
    expect(first.height, 256);
    expect(first.policy, ResizeImagePolicy.fit);
    expect(
      await first.obtainKey(ImageConfiguration.empty),
      await images.last.image.obtainKey(ImageConfiguration.empty),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('1000 catalog items and categories build only visible cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          katalogControllerProvider.overrideWith(_Catalog.new),
          businessProfileProvider.overrideWith((ref) async => null),
        ],
        child: const MaterialApp(home: Scaffold(body: KatalogPage())),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Produk 0'), findsOneWidget);
    expect(find.text('Produk 999'), findsNothing);
    expect(find.textContaining('Produk ').evaluate().length, lessThan(30));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -700));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kategori').first);
    await tester.pumpAndSettle();
    expect(find.byType(SliverGrid), findsOneWidget);
    expect(find.text('Kategori 999'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
