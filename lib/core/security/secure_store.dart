import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final class SecureStore {
  SecureStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  Future<String?> read(String key) async {
    try {
      return await _storage.read(key: key);
    } on Object catch (error) {
      throw SecureStoreException.read(error);
    }
  }

  Future<bool> hasValue(String key) async {
    final value = await read(key);
    return value != null && value.isNotEmpty;
  }

  Future<void> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
    } on Object catch (error) {
      throw SecureStoreException.write(error);
    }
  }

  Future<void> delete(String key) async {
    try {
      await _storage.delete(key: key);
    } on Object catch (error) {
      throw SecureStoreException.delete(error);
    }
  }
}

final class SecureStoreException implements Exception {
  const SecureStoreException._(this.message, this.cause);

  factory SecureStoreException.read(Object cause) {
    return SecureStoreException._('无法读取安全存储，请检查系统凭据服务或应用权限。', cause);
  }

  factory SecureStoreException.write(Object cause) {
    return SecureStoreException._('无法写入安全存储，请检查系统凭据服务或应用权限。', cause);
  }

  factory SecureStoreException.delete(Object cause) {
    return SecureStoreException._('无法清除安全存储，请检查系统凭据服务或应用权限。', cause);
  }

  final String message;
  final Object cause;

  @override
  String toString() => message;
}
