import 'reader_settings.dart';

abstract interface class SettingsRepository {
  Stream<ReaderSettings> watchReaderSettings();

  Future<ReaderSettings> getReaderSettings();

  Future<void> saveReaderSettings(ReaderSettings settings);
}
