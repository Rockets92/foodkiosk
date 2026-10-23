import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;
import 'package:pointycastle/export.dart';

import 'database.dart';

/// Encrypted store for credentials (the Agenzia delle Entrate account,
/// provider API keys). Nothing in it is ever sent back by the API.
///
/// Each entry is sealed with AES-256-GCM and kept in the database; the key
/// lives in a separate file in the data folder, so a copy of the database
/// alone reveals nothing. On Windows the key file is in turn protected
/// with DPAPI and only opens on this PC.
class SecretStore {
  final AppDatabase _db;
  final Uint8List _key;

  SecretStore._(this._db, this._key);

  /// A random key that only lives in memory: for tests and in-memory
  /// databases.
  factory SecretStore.ephemeral(AppDatabase db) =>
      SecretStore._(db, _randomBytes(32));

  /// Uses (or creates on first start) the key file `secret.key` in
  /// [dataDir].
  factory SecretStore.open(AppDatabase db, String dataDir) {
    final file = File(p.join(dataDir, 'secret.key'));
    if (file.existsSync()) {
      return SecretStore._(db, _readKey(file.readAsBytesSync()));
    }
    final key = _randomBytes(32);
    file.writeAsBytesSync(_writeKey(key), flush: true);
    if (!Platform.isWindows) {
      try {
        Process.runSync('chmod', ['600', file.path]);
      } on ProcessException {
        // Best effort: the folder itself is private to the service.
      }
    }
    return SecretStore._(db, key);
  }

  static const _dpapiMagic = 'FKDPAPI1';

  static Uint8List _writeKey(Uint8List key) => Platform.isWindows
      ? Uint8List.fromList([
          ...ascii.encode(_dpapiMagic),
          ..._Dpapi.protect(key),
        ])
      : key;

  static Uint8List _readKey(Uint8List bytes) {
    if (bytes.length > _dpapiMagic.length &&
        ascii.decode(
              bytes.sublist(0, _dpapiMagic.length),
              allowInvalid: true,
            ) ==
            _dpapiMagic) {
      return _Dpapi.unprotect(bytes.sublist(_dpapiMagic.length));
    }
    if (bytes.length != 32) {
      throw const FormatException('secret.key is damaged');
    }
    return bytes;
  }

  static String _slot(String name) => 'secret:$name';

  bool contains(String name) => _db.readSetting(_slot(name)) != null;

  /// The entry, or null when missing or when it cannot be opened (the key
  /// file was replaced): the credentials then have to be entered again.
  Map<String, String>? read(String name) {
    final sealed = _db.readSetting(_slot(name));
    if (sealed is! Map) return null;
    try {
      final iv = base64.decode(sealed['iv'] as String);
      final data = base64.decode(sealed['data'] as String);
      final plain = _cipher(false, iv, name).process(data);
      return (jsonDecode(utf8.decode(plain)) as Map).cast<String, String>();
    } on Object {
      return null;
    }
  }

  void write(String name, Map<String, String> values) {
    final iv = _randomBytes(12);
    final data = _cipher(
      true,
      iv,
      name,
    ).process(Uint8List.fromList(utf8.encode(jsonEncode(values))));
    _db.writeSetting(_slot(name), {
      'v': 1,
      'iv': base64.encode(iv),
      'data': base64.encode(data),
    });
  }

  void delete(String name) => _db.deleteSetting(_slot(name));

  /// The entry name is authenticated too, so a sealed value cannot be
  /// moved to another entry.
  GCMBlockCipher _cipher(bool encrypt, Uint8List iv, String name) =>
      GCMBlockCipher(AESEngine())..init(
        encrypt,
        AEADParameters(
          KeyParameter(_key),
          128,
          iv,
          Uint8List.fromList(utf8.encode(name)),
        ),
      );

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList([for (var i = 0; i < n; i++) r.nextInt(256)]);
  }
}

/// Windows Data Protection API (crypt32.dll), machine scope: the data only
/// opens on the PC that protected it.
abstract final class _Dpapi {
  static const _uiForbidden = 0x1;
  static const _localMachine = 0x4;

  static final _crypt32 = DynamicLibrary.open('crypt32.dll');
  static final _kernel32 = DynamicLibrary.open('kernel32.dll');

  static final _protect = _crypt32
      .lookupFunction<_CryptProtectNative, _CryptProtectDart>(
        'CryptProtectData',
      );
  static final _unprotect = _crypt32
      .lookupFunction<_CryptUnprotectNative, _CryptUnprotectDart>(
        'CryptUnprotectData',
      );
  static final _localFree = _kernel32
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>),
        Pointer<Void> Function(Pointer<Void>)
      >('LocalFree');

  static Uint8List protect(Uint8List data) => _run(data, encrypt: true);
  static Uint8List unprotect(Uint8List data) => _run(data, encrypt: false);

  static Uint8List _run(Uint8List data, {required bool encrypt}) => using((
    arena,
  ) {
    final input = arena<_DataBlob>();
    final output = arena<_DataBlob>();
    final buffer = arena<Uint8>(data.length);
    buffer.asTypedList(data.length).setAll(0, data);
    input.ref
      ..cbData = data.length
      ..pbData = buffer;
    final flags = _uiForbidden | _localMachine;
    final ok = encrypt
        ? _protect(input, nullptr, nullptr, nullptr, nullptr, flags, output)
        : _unprotect(input, nullptr, nullptr, nullptr, nullptr, flags, output);
    if (ok == 0) {
      throw const FileSystemException(
        'DPAPI could not open secret.key (copied from another PC?)',
      );
    }
    try {
      return Uint8List.fromList(
        output.ref.pbData.asTypedList(output.ref.cbData),
      );
    } finally {
      _localFree(output.ref.pbData.cast());
    }
  });
}

final class _DataBlob extends Struct {
  @Uint32()
  external int cbData;
  external Pointer<Uint8> pbData;
}

typedef _CryptProtectNative =
    Int32 Function(
      Pointer<_DataBlob>,
      Pointer<Utf16>,
      Pointer<_DataBlob>,
      Pointer<Void>,
      Pointer<Void>,
      Uint32,
      Pointer<_DataBlob>,
    );
typedef _CryptProtectDart =
    int Function(
      Pointer<_DataBlob>,
      Pointer<Utf16>,
      Pointer<_DataBlob>,
      Pointer<Void>,
      Pointer<Void>,
      int,
      Pointer<_DataBlob>,
    );
typedef _CryptUnprotectNative =
    Int32 Function(
      Pointer<_DataBlob>,
      Pointer<Pointer<Utf16>>,
      Pointer<_DataBlob>,
      Pointer<Void>,
      Pointer<Void>,
      Uint32,
      Pointer<_DataBlob>,
    );
typedef _CryptUnprotectDart =
    int Function(
      Pointer<_DataBlob>,
      Pointer<Pointer<Utf16>>,
      Pointer<_DataBlob>,
      Pointer<Void>,
      Pointer<Void>,
      int,
      Pointer<_DataBlob>,
    );
