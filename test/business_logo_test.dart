import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:pujangga_pos/core/database/app_database.dart';
import 'package:pujangga_pos/core/errors/app_exception.dart';
import 'package:pujangga_pos/core/services/business_logo_service.dart';
import 'package:pujangga_pos/core/services/app_startup_service.dart';
import 'package:pujangga_pos/features/pengaturan/presentation/controllers/pengaturan_profil_controller.dart';
import 'package:pujangga_pos/features/setup_usaha/domain/repositories/business_profile_repository.dart';
import 'package:pujangga_pos/features/setup_usaha/presentation/controllers/setup_usaha_controller.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_backup_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_reset_service.dart';
import 'package:pujangga_pos/features/pengaturan/data/services/app_restore_service.dart';
import 'package:pujangga_pos/features/pengaturan/domain/entities/app_backup_restore_candidate.dart';
import 'package:pujangga_pos/features/setup_usaha/data/datasources/business_profile_local_data_source.dart';
import 'package:pujangga_pos/features/setup_usaha/data/repositories/business_profile_repository_impl.dart';
import 'package:pujangga_pos/features/setup_usaha/domain/entities/business_profile.dart';
import 'package:pujangga_pos/features/setup_usaha/presentation/widgets/business_profile_dialog.dart';
import 'package:pujangga_pos/shared/widgets/business_logo.dart';
import 'package:pujangga_pos/shared/widgets/logo_picker.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

Future<Uint8List> png(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width / 2, height / 2),
    Paint()..color = Colors.teal,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

Future<(int, int)> dimensions(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final image = (await codec.getNextFrame()).image;
  try {
    return (image.width, image.height);
  } finally {
    image.dispose();
    codec.dispose();
  }
}

class _FailingLogoStore extends BusinessLogoService {
  _FailingLogoStore(Directory root) : super(supportDirectory: () async => root);
  @override
  Future<String> write(Uint8List png, {bool draft = false}) async =>
      throw const FileSystemException('Synthetic write failure');
}

class _FailingProfileRepository implements BusinessProfileRepository {
  @override
  Future<bool> hasProfile() async => true;
  @override
  Future<BusinessProfile?> getProfile() async => null;
  @override
  Future<void> saveProfile(BusinessProfile profile) async =>
      throw const AppException('qa_failure', 'Synthetic save failure');
}

class _SuccessfulProfileRepository extends _FailingProfileRepository {
  @override
  Future<void> saveProfile(BusinessProfile profile) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory temp;
  late BusinessLogoService logos;
  late AppDatabase database;
  late BusinessProfileRepositoryImpl repository;
  const profile = BusinessProfile(
    businessName: 'Logo QA',
    businessType: 'retail',
  );

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });
  setUp(() async {
    temp = await Directory.systemTemp.createTemp('pujangga_logo_test_');
    await databaseFactory.setDatabasesPath(p.join(temp.path, 'db'));
    database = AppDatabase();
    logos = BusinessLogoService(
      supportDirectory: () async => Directory(p.join(temp.path, 'support')),
      temporaryDirectory: () async => Directory(p.join(temp.path, 'tmp')),
    );
    repository = BusinessProfileRepositoryImpl(
      localDataSource: BusinessProfileLocalDataSource(database: database),
      logger: Logger.root,
      logoService: logos,
    );
  });
  tearDown(() async {
    await database.reset();
    await temp.delete(recursive: true);
  });

  Future<File> source({int width = 40, int height = 20}) async {
    final file = File(p.join(temp.path, 'source.png'));
    await file.writeAsBytes(await png(width, height));
    return file;
  }

  Future<AppBackupRestoreCandidate> backupCandidate() async {
    final backup = await AppBackupService(
      database: database,
      logger: Logger.root,
      logoService: logos,
      backupDirectoryProvider: () async =>
          Directory(p.join(temp.path, 'backup')),
    ).createBackup();
    return AppRestoreService(
      database: database,
      logger: Logger.root,
      logoService: logos,
    ).inspectBackupFile(backup.filePath);
  }

  test('normalizes large, wide and tall PNGs without upscaling or losing transparency', () async {
    for (final size in [(4096, 4096), (2048, 512), (512, 2048), (40, 20)]) {
      final result = await logos.normalize(await png(size.$1, size.$2));
      final scale = size.$1 > size.$2 ? size.$1 : size.$2;
      final factor = scale > 1024 ? 1024 / scale : 1;
      expect(await dimensions(result), (
        (size.$1 * factor).round(),
        (size.$2 * factor).round(),
      ));
      final codec = await ui.instantiateImageCodec(result);
      final image = (await codec.getNextFrame()).image;
      final rgba = (await image.toByteData())!;
      expect(rgba.getUint8(rgba.lengthInBytes - 1), 0);
      image.dispose();
      codec.dispose();
    }
  });

  test(
    'rejects corrupt, unsupported, oversized sources and excessive dimensions',
    () async {
      for (final bytes in [
        Uint8List.fromList([1, 2, 3]),
        Uint8List(BusinessLogoService.maxInputBytes + 1),
        await png(8193, 1),
        await png(5000, 4000),
      ]) {
        await expectLater(logos.normalize(bytes), throwsA(isA<AppException>()));
      }
      await expectLater(
        logos.normalize(await png(1025, 10), backup: true),
        throwsA(isA<AppException>()),
      );
    },
  );

  test(
    'accepts JPEG and static WebP and rejects animated WebP and PNG',
    () async {
      for (final name in ['logo-jpeg.jpg', 'logo-webp.webp']) {
        final result = await logos.normalize(
          await File(p.join('test', 'fixtures', name)).readAsBytes(),
        );
        expect(await dimensions(result), (64, 32));
      }
      for (final name in ['logo-animated.webp', 'logo-animated.png']) {
        await expectLater(
          logos.normalize(
            await File(p.join('test', 'fixtures', name)).readAsBytes(),
          ),
          throwsA(isA<AppException>()),
        );
      }
    },
  );

  test('imports, replaces, clears and reloads managed logos without deleting the source', () async {
    final original = await source();
    await repository.saveProfile(profile.copyWith(logoPath: original.path));
    final first = (await repository.getProfile())!;
    expect(await logos.owns(first.logoPath!), isTrue);
    await original.delete();
    expect(await File(first.logoPath!).exists(), isTrue);
    final nextSource = await source(width: 20, height: 40);
    await repository.saveProfile(first.copyWith(logoPath: nextSource.path));
    final second = (await repository.getProfile())!;
    expect(second.logoPath, isNot(first.logoPath));
    expect(await File(first.logoPath!).exists(), isFalse);
    expect(await nextSource.exists(), isTrue);
    await repository.saveProfile(second.copyWith(logoPath: null));
    expect((await repository.getProfile())!.logoPath, isNull);
    expect(await File(second.logoPath!).exists(), isFalse);
    expect(await nextSource.exists(), isTrue);
  });

  test(
    'failed database commit keeps old logo and removes newly created file',
    () async {
      final original = await source();
      await repository.saveProfile(profile.copyWith(logoPath: original.path));
      final old = (await repository.getProfile())!;
      final db = await database.database();
      await db.execute(
        "CREATE TRIGGER fail_profile BEFORE UPDATE ON business_profile BEGIN SELECT RAISE(ABORT, 'qa_failure'); END",
      );
      await expectLater(
        repository.saveProfile(old.copyWith(logoPath: original.path)),
        throwsA(anything),
      );
      expect((await repository.getProfile())!.logoPath, old.logoPath);
      expect(await File(old.logoPath!).exists(), isTrue);
      final files = await Directory(p.dirname(old.logoPath!)).list().toList();
      expect(files, hasLength(1));
    },
  );

  test(
    'editing a profile does not reload startup or reset the router',
    () async {
      var startupLoads = 0;
      final container = ProviderContainer(
        overrides: [
          businessProfileRepositoryProvider.overrideWithValue(
            _SuccessfulProfileRepository(),
          ),
          appStartupProvider.overrideWith((ref) async {
            startupLoads++;
            return const AppStartupState(hasBusinessProfile: true);
          }),
        ],
      );
      addTearDown(container.dispose);
      final subscription = container.listen(appStartupProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(appStartupProvider.future);
      await container.read(pengaturanProfilControllerProvider.future);
      await container
          .read(pengaturanProfilControllerProvider.notifier)
          .save(profile);
      await Future<void>.delayed(Duration.zero);
      expect(startupLoads, 1);
    },
  );

  test('storage failure keeps the existing profile and logo', () async {
    final original = await source();
    await repository.saveProfile(profile.copyWith(logoPath: original.path));
    final old = (await repository.getProfile())!;
    final failing = BusinessProfileRepositoryImpl(
      localDataSource: BusinessProfileLocalDataSource(database: database),
      logger: Logger.root,
      logoService: _FailingLogoStore(Directory(p.join(temp.path, 'support'))),
    );
    await expectLater(
      failing.saveProfile(old.copyWith(logoPath: original.path)),
      throwsA(isA<FileSystemException>()),
    );
    expect((await repository.getProfile())!.logoPath, old.logoPath);
    expect(await File(old.logoPath!).exists(), isTrue);
  });

  test(
    'profile and setup controllers propagate save failure to their caller',
    () async {
      final container = ProviderContainer(
        overrides: [
          businessProfileRepositoryProvider.overrideWithValue(
            _FailingProfileRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);
      await container.read(pengaturanProfilControllerProvider.future);
      await expectLater(
        container
            .read(pengaturanProfilControllerProvider.notifier)
            .save(profile),
        throwsA(isA<AppException>()),
      );
      expect(
        container.read(pengaturanProfilControllerProvider).hasError,
        isTrue,
      );
      await container.read(setupUsahaControllerProvider.future);
      await expectLater(
        container
            .read(setupUsahaControllerProvider.notifier)
            .submit(businessProfile: profile),
        throwsA(isA<AppException>()),
      );
      expect(container.read(setupUsahaControllerProvider).hasError, isTrue);
    },
  );

  test('an invalid new logo cannot replace the profile; unchanged broken legacy path is preserved', () async {
    final missing = p.join(temp.path, 'missing.png');
    await repository.saveProfile(profile);
    await expectLater(
      repository.saveProfile(profile.copyWith(logoPath: missing)),
      throwsA(isA<FileSystemException>()),
    );
    expect((await repository.getProfile())!.logoPath, isNull);
    final db = await database.database();
    await db.update('business_profile', {'logo_path': missing});
    await repository.saveProfile(
      profile.copyWith(logoPath: missing, businessName: 'Renamed'),
    );
    expect((await repository.getProfile())!.logoPath, missing);
  });

  test('backup v3 embeds PNG, removes source path and restores to a different sandbox', () async {
    final original = await source();
    await repository.saveProfile(profile.copyWith(logoPath: original.path));
    final old = (await repository.getProfile())!.logoPath!;
    final candidate = await backupCandidate();
    final payload =
        jsonDecode(await File(candidate.filePath).readAsString()) as Map;
    expect(payload['format_version'], 3);
    expect(
      (payload['tables']['business_profile'] as List).single['logo_path'],
      isNull,
    );
    expect(candidate.businessLogoBytes, isNotNull);
    final destination = BusinessLogoService(
      supportDirectory: () async => Directory(p.join(temp.path, 'destination')),
    );
    await AppRestoreService(
      database: database,
      logger: Logger.root,
      logoService: destination,
    ).restoreBackup(candidate);
    final restored = (await repository.getProfile())!.logoPath!;
    expect(restored, isNot(old));
    expect(await destination.owns(restored), isTrue);
    expect(await File(restored).readAsBytes(), candidate.businessLogoBytes);
    expect(await original.exists(), isTrue);
  });

  test(
    'legacy v2 restores business data without trusting a foreign file path',
    () async {
      await repository.saveProfile(profile);
      final candidate = await backupCandidate();
      final payload =
          jsonDecode(await File(candidate.filePath).readAsString()) as Map;
      payload['format_version'] = 2;
      payload.remove('assets');
      payload['tables']['business_profile'][0]['logo_path'] =
          '/some/other/device/logo.png';
      await File(candidate.filePath).writeAsString(jsonEncode(payload));
      final service = AppRestoreService(
        database: database,
        logger: Logger.root,
        logoService: logos,
      );
      final legacy = await service.inspectBackupFile(candidate.filePath);
      expect(legacy.warnings, isNotEmpty);
      await service.restoreBackup(legacy);
      expect((await repository.getProfile())!.logoPath, isNull);
      expect(
        (await repository.getProfile())!.businessName,
        profile.businessName,
      );
    },
  );

  test('invalid backup image is rejected before replacing any data', () async {
    await repository.saveProfile(profile);
    final candidate = await backupCandidate();
    final payload =
        jsonDecode(await File(candidate.filePath).readAsString()) as Map;
    for (final asset in [
      {'mime_type': 'image/png', 'data_base64': 'not-base64'},
      {
        'mime_type': 'image/png',
        'data_base64': base64Encode(await png(1025, 1)),
      },
      {'mime_type': 'image/jpeg', 'data_base64': ''},
    ]) {
      payload['assets']['business_logo'] = asset;
      await File(candidate.filePath).writeAsString(jsonEncode(payload));
      await expectLater(
        AppRestoreService(
          database: database,
          logger: Logger.root,
          logoService: logos,
        ).inspectBackupFile(candidate.filePath),
        throwsA(isA<AppException>()),
      );
      expect(
        (await repository.getProfile())!.businessName,
        profile.businessName,
      );
    }
  });

  test(
    'restore rollback keeps previous database and logo and cleans new asset',
    () async {
      final original = await source();
      await repository.saveProfile(profile.copyWith(logoPath: original.path));
      final old = (await repository.getProfile())!;
      final candidate = await backupCandidate();
      final db = await database.database();
      await db.execute(
        "CREATE TRIGGER fail_restore BEFORE INSERT ON business_profile BEGIN SELECT RAISE(ABORT, 'qa_failure'); END",
      );
      await expectLater(
        AppRestoreService(
          database: database,
          logger: Logger.root,
          logoService: logos,
        ).restoreBackup(candidate),
        throwsA(anything),
      );
      expect((await repository.getProfile())!.logoPath, old.logoPath);
      expect(await File(old.logoPath!).exists(), isTrue);
      expect(await Directory(p.dirname(old.logoPath!)).list().length, 1);
    },
  );

  test('missing export logo warns while preserving business backup', () async {
    await repository.saveProfile(profile);
    final db = await database.database();
    await db.update('business_profile', {
      'logo_path': p.join(temp.path, 'missing.png'),
    });
    final backup = await AppBackupService(
      database: database,
      logger: Logger.root,
      logoService: logos,
      backupDirectoryProvider: () async => temp,
    ).createBackup();
    expect(backup.warnings, isNotEmpty);
    expect(
      jsonDecode(
        await File(backup.filePath).readAsString(),
      )['assets']['business_logo'],
      isNull,
    );
    expect(backup.recordCounts['business_profile'], 1);
  });

  test('startup and reset remove only owned, unreferenced files', () async {
    final original = await source();
    await repository.saveProfile(profile.copyWith(logoPath: original.path));
    final active = (await repository.getProfile())!.logoPath!;
    final orphan = await logos.write(await png(10, 10));
    final draft = await logos.write(await png(10, 10), draft: true);
    await logos.cleanupOnStartup(() async => active);
    expect(await File(active).exists(), isTrue);
    expect(await File(orphan).exists(), isFalse);
    expect(await File(draft).exists(), isFalse);
    expect(await original.exists(), isTrue);
    await AppResetService(
      database: database,
      logger: Logger.root,
      logoService: logos,
    ).resetAppData();
    expect(await File(active).exists(), isFalse);
    expect(await original.exists(), isTrue);
  });

  testWidgets(
    'missing and corrupt logos show a fallback with no uncaught image error',
    (tester) async {
      final broken = File(p.join(temp.path, 'broken.png'));
      await tester.runAsync(() => broken.writeAsString('invalid image'));
      for (final logoPath in [
        null,
        p.join(temp.path, 'missing.png'),
        broken.path,
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: SizedBox(
              width: 40,
              height: 40,
              child: BusinessLogo(path: logoPath),
            ),
          ),
        );
        for (var i = 0; i < 4; i++) {
          await tester.runAsync(
            () async => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.storefront), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      await tester.runAsync(
        () async => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump();
    },
  );

  testWidgets(
    'a selected logo is a temporary draft and cancelling removes it',
    (tester) async {
      final file = (await tester.runAsync(() => source()))!;
      String? selected;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessLogoServiceProvider.overrideWithValue(logos),
            logoFilePickerProvider.overrideWithValue(() async => file.path),
          ],
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: LogoPicker(
                  path: selected,
                  onChanged: (path) => setState(() => selected = path),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Pilih Logo'));
      for (var i = 0; i < 30 && selected == null; i++) {
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
      }
      expect(selected, isNotNull);
      expect(
        await tester.runAsync(() => logos.owns(selected!, draft: true)),
        isTrue,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () async => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump();
      }
      expect(await tester.runAsync(() => File(selected!).exists()), isFalse);
      expect(await tester.runAsync(() => file.exists()), isTrue);
    },
  );

  testWidgets(
    'picker cancellation and failed save preserve the dialog and existing logo',
    (tester) async {
      BusinessProfile? submitted;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            businessLogoServiceProvider.overrideWithValue(logos),
            logoFilePickerProvider.overrideWithValue(() async => null),
          ],
          child: MaterialApp(
            home: BusinessProfileDialog(
              profile: profile.copyWith(logoPath: 'unchanged'),
              onSave: (value) async {
                submitted = value;
                return false;
              },
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Pilih Logo'));
      await tester.tap(find.text('Pilih Logo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(submitted!.logoPath, 'unchanged');
      expect(find.text('Edit Profil Usaha'), findsOneWidget);
      await tester.ensureVisible(find.text('Hapus Logo'));
      await tester.tap(find.text('Hapus Logo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();
      expect(submitted!.logoPath, isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
