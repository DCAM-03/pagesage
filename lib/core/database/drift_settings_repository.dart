import '../../domain/books/reader_settings.dart';
import '../../domain/books/settings_repository.dart';
import 'app_database.dart';

const _readerSettingsKey = 'reader.settings';

final class DriftSettingsRepository implements SettingsRepository {
  const DriftSettingsRepository(this._settingsDao);

  final SettingsDao _settingsDao;

  @override
  Stream<ReaderSettings> watchReaderSettings() {
    return _settingsDao.watchSettings().map((settings) {
      AppSettingRow? row;
      for (final setting in settings) {
        if (setting.key == _readerSettingsKey) {
          row = setting;
          break;
        }
      }
      return ReaderSettings.fromJsonText(row?.value);
    });
  }

  @override
  Future<ReaderSettings> getReaderSettings() async {
    final value = await _settingsDao.getValue(_readerSettingsKey);
    return ReaderSettings.fromJsonText(value);
  }

  @override
  Future<void> saveReaderSettings(ReaderSettings settings) {
    return _settingsDao.setValue(
      _readerSettingsKey,
      settings.toJsonText(),
      DateTime.now().millisecondsSinceEpoch,
    );
  }
}
