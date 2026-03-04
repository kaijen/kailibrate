import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiKeyService {
  static const _storage = FlutterSecureStorage();
  static const _keyName = 'openrouter_api_key';
  static const _modelKey = 'openrouter_model';
  static const _modelListKey = 'openrouter_model_list';

  static Future<String?> getKey() => _storage.read(key: _keyName);
  static Future<bool> hasKey() async {
    final k = await _storage.read(key: _keyName);
    return k != null && k.isNotEmpty;
  }
  static Future<void> saveKey(String v) => _storage.write(key: _keyName, value: v);
  static Future<void> deleteKey() => _storage.delete(key: _keyName);
  static Future<String?> getModel() => _storage.read(key: _modelKey);
  static Future<void> saveModel(String v) => _storage.write(key: _modelKey, value: v);

  static Future<List<String>> getModelList() async {
    final raw = await _storage.read(key: _modelListKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveModelList(List<String> models) async {
    await _storage.write(key: _modelListKey, value: jsonEncode(models));
  }
}
