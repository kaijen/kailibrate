import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import 'api_key_service.dart';
import 'prompt_template_service.dart';

// ---------------------------------------------------------------------------
// Top-level functions executed in a separate isolate via compute().
// They must be top-level (not instance methods) and use only transferable
// types (String, int, List<int>).
// ---------------------------------------------------------------------------

Future<Map<String, dynamic>> _encryptPayload(
    Map<String, dynamic> params) async {
  final password = params['password'] as String;
  final salt = List<int>.from(params['salt'] as List);
  final nonce = List<int>.from(params['nonce'] as List);
  final plaintext = List<int>.from(params['plaintext'] as List);
  final iterations = params['iterations'] as int;

  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );
  final secretKey = await pbkdf2.deriveKeyFromPassword(
    password: password,
    nonce: salt,
  );

  final aesGcm = AesGcm.with256bits();
  final secretBox = await aesGcm.encrypt(
    plaintext,
    secretKey: secretKey,
    nonce: nonce,
  );

  return {
    'ciphertext': secretBox.cipherText,
    'mac': secretBox.mac.bytes,
  };
}

Future<List<int>> _decryptPayload(Map<String, dynamic> params) async {
  final password = params['password'] as String;
  final salt = List<int>.from(params['salt'] as List);
  final nonce = List<int>.from(params['nonce'] as List);
  final ciphertext = List<int>.from(params['ciphertext'] as List);
  final mac = List<int>.from(params['mac'] as List);
  final iterations = params['iterations'] as int;

  final pbkdf2 = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: iterations,
    bits: 256,
  );
  final secretKey = await pbkdf2.deriveKeyFromPassword(
    password: password,
    nonce: salt,
  );

  final aesGcm = AesGcm.with256bits();
  try {
    return await aesGcm.decrypt(
      SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
      secretKey: secretKey,
    );
  } on SecretBoxAuthenticationError {
    // Sentinel recognized by the caller.
    throw Exception('WRONG_PASSWORD');
  }
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

class BackupException implements Exception {
  final String message;
  const BackupException(this.message);

  @override
  String toString() => message;
}

class BackupService {
  static const int _backupVersion = 1;
  static const int _pbkdf2Iterations = 200000;
  static const int _saltBytes = 16;
  static const int _nonceBytes = 12;

  static List<int> _randomBytes(int n) {
    final rng = Random.secure();
    return List.generate(n, (_) => rng.nextInt(256));
  }

  /// Creates an encrypted backup and returns the JSON string.
  ///
  /// Format (outer JSON, version 1):
  /// ```json
  /// {
  ///   "version": 1,
  ///   "createdAt": "<ISO-8601>",
  ///   "kdf": { "algorithm": "PBKDF2-HMAC-SHA256",
  ///            "iterations": 200000, "salt": "<base64>" },
  ///   "cipher": "AES-256-GCM",
  ///   "nonce": "<base64>",
  ///   "mac":   "<base64>",
  ///   "ciphertext": "<base64>"
  /// }
  /// ```
  static Future<String> createBackup({
    required AppDatabase db,
    required String password,
  }) async {
    final dbData = await db.exportForBackup();
    final apiKey = await ApiKeyService.getKey();
    final model = await ApiKeyService.getModel();
    final modelList = await ApiKeyService.getModelList();
    final templates = await PromptTemplateService.loadAll();
    final userTemplates = templates
        .where((t) => !t.isDefault)
        .map((t) => t.toJson())
        .toList();
    final prefs = await SharedPreferences.getInstance();
    final hiddenDefaults =
        prefs.getStringList('prompt_templates_hidden_v1') ?? [];

    final payloadJson = jsonEncode({
      'version': _backupVersion,
      'db': dbData,
      'config': {
        if (apiKey != null && apiKey.isNotEmpty) 'openrouterApiKey': apiKey,
        if (model != null && model.isNotEmpty) 'openrouterModel': model,
        'openrouterModelList': modelList,
        'userTemplates': userTemplates,
        'hiddenDefaultTemplates': hiddenDefaults,
      },
    });

    final plaintext = utf8.encode(payloadJson);
    final salt = _randomBytes(_saltBytes);
    final nonce = _randomBytes(_nonceBytes);

    final encrypted = await compute(_encryptPayload, {
      'password': password,
      'salt': salt,
      'nonce': nonce,
      'plaintext': plaintext,
      'iterations': _pbkdf2Iterations,
    });

    return const JsonEncoder.withIndent('  ').convert({
      'version': _backupVersion,
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'kdf': {
        'algorithm': 'PBKDF2-HMAC-SHA256',
        'iterations': _pbkdf2Iterations,
        'salt': base64Encode(salt),
      },
      'cipher': 'AES-256-GCM',
      'nonce': base64Encode(nonce),
      'mac': base64Encode(encrypted['mac'] as List<int>),
      'ciphertext': base64Encode(encrypted['ciphertext'] as List<int>),
    });
  }

  /// Restores all data from an encrypted backup.
  ///
  /// Throws [BackupException] for wrong password, corrupt data, or
  /// unsupported backup version.
  static Future<void> restoreBackup({
    required AppDatabase db,
    required String backupJson,
    required String password,
  }) async {
    final Map<String, dynamic> outer;
    try {
      outer = jsonDecode(backupJson) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException('Keine gültige Backup-Datei (kein JSON).');
    }

    final version = (outer['version'] as num?)?.toInt();
    if (version == null || version > _backupVersion) {
      throw const BackupException(
          'Backup-Version nicht unterstützt. Bitte App aktualisieren.');
    }

    final kdf = outer['kdf'] as Map<String, dynamic>?;
    if (kdf == null) {
      throw const BackupException('KDF-Parameter fehlen im Backup.');
    }
    final iterations =
        (kdf['iterations'] as num?)?.toInt() ?? _pbkdf2Iterations;
    final salt = base64Decode(kdf['salt'] as String);
    final nonce = base64Decode(outer['nonce'] as String);
    final mac = base64Decode(outer['mac'] as String);
    final ciphertext = base64Decode(outer['ciphertext'] as String);

    final List<int> plaintext;
    try {
      plaintext = await compute(_decryptPayload, {
        'password': password,
        'salt': List<int>.from(salt),
        'nonce': List<int>.from(nonce),
        'mac': List<int>.from(mac),
        'ciphertext': List<int>.from(ciphertext),
        'iterations': iterations,
      });
    } catch (e) {
      if (e.toString().contains('WRONG_PASSWORD')) {
        throw const BackupException(
            'Falsches Passwort oder beschädigte Datei.');
      }
      throw BackupException('Entschlüsselung fehlgeschlagen: $e');
    }

    final Map<String, dynamic> payload;
    try {
      payload = jsonDecode(utf8.decode(plaintext)) as Map<String, dynamic>;
    } catch (_) {
      throw const BackupException(
          'Backup-Inhalt konnte nicht gelesen werden.');
    }

    final dbData = payload['db'] as Map<String, dynamic>?;
    if (dbData == null) {
      throw const BackupException('DB-Daten fehlen im Backup.');
    }
    await db.restoreFromBackup(dbData);

    final config = payload['config'] as Map<String, dynamic>? ?? {};

    final apiKey = config['openrouterApiKey'] as String?;
    if (apiKey != null && apiKey.isNotEmpty) {
      await ApiKeyService.saveKey(apiKey);
    }

    final savedModel = config['openrouterModel'] as String?;
    if (savedModel != null && savedModel.isNotEmpty) {
      await ApiKeyService.saveModel(savedModel);
    }

    final modelList =
        (config['openrouterModelList'] as List?)?.cast<String>() ?? [];
    await ApiKeyService.saveModelList(modelList);

    for (final t in (config['userTemplates'] as List? ?? [])) {
      final template = PromptTemplate.fromJson(t as Map<String, dynamic>);
      await PromptTemplateService.save(template);
    }

    final hiddenDefaults =
        (config['hiddenDefaultTemplates'] as List?)?.cast<String>() ?? [];
    if (hiddenDefaults.isNotEmpty) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('prompt_templates_hidden_v1', hiddenDefaults);
    }
  }
}
