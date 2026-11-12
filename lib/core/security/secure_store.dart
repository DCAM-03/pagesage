import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStore {
  SecureStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage(),
      _memory = null;

  SecureStore.memory({Map<String, String>? seed})
    : _storage = null,
      _memory = {...?seed};

  final FlutterSecureStorage? _storage;
  final Map<String, String>? _memory;

  Future<String?> read(String key) async {
    final memory = _memory;
    if (memory != null) return memory[key];
    try {
      return await _storage!.read(key: key);
    } on Object catch (error) {
      throw SecureStoreException.read(error);
    }
  }

  Future<bool> hasValue(String key) async {
    final value = await read(key);
    return value != null && value.isNotEmpty;
  }

  Future<void> write(String key, String value) async {
    final memory = _memory;
    if (memory != null) {
      memory[key] = value;
      return;
    }
    try {
      await _storage!.write(key: key, value: value);
    } on Object catch (error) {
      throw SecureStoreException.write(error);
    }
  }

  Future<void> delete(String key) async {
    final memory = _memory;
    if (memory != null) {
      memory.remove(key);
      return;
    }
    try {
      await _storage!.delete(key: key);
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
