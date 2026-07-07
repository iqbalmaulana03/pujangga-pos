import '../../domain/entities/app_settings.dart';
import '../../domain/repositories/settings_repository.dart';
import '../datasources/app_settings_local_data_source.dart';
import '../models/app_settings_db_model.dart';

class SettingsRepositoryImpl implements SettingsRepository {
  const SettingsRepositoryImpl({required this.localDataSource});

  final AppSettingsLocalDataSource localDataSource;

  @override
  Future<AppSettings?> getSettings() async {
    final settings = await localDataSource.getSettings();
    return settings?.toEntity();
  }

  @override
  Future<void> saveSettings(AppSettings settings) {
    return localDataSource.saveSettings(
      AppSettingsDbModel.fromEntity(settings),
    );
  }
}
