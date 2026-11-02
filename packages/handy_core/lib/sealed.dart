import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

/// Password-protected backups that can be written without the password.
///
/// [SealKey.create] makes an X25519 key pair and keeps the private half only
/// wrapped by a key derived from the password (PBKDF2-HMAC-SHA256). The app
/// stores the [SealKey]: it holds the public key and the wrapped private key,
/// never the password or anything that opens a backup on its own. Every
/// backup then uses a fresh ephemeral key pair, HKDF-SHA256 and AES-256-GCM,
/// and carries the wrapped private key, so [unseal] needs only the file and
/// the password. A forgotten password cannot be recovered.
///
/// Layout (big-endian), all of it authenticated:
/// `HNDYSEAL` · version 1 · iterations u32 · salt 16 · wrap nonce 12 ·
/// wrapped private key 48 · recipient public key 32 · ephemeral public key 32
/// · nonce 12 · ciphertext · tag 16.
const sealMagic = 'HNDYSEAL';
const sealExtension = 'hseal';
const sealIterations = 600000;
const _version = 1, _minIterations = 10000, _maxIterations = 10000000;
const _headerLength = 8 + 1 + 4 + 16 + 12 + 48 + 32 + 32 + 12;

enum SealFailure { notSealed, unsupported, wrongPassword, damaged }

class SealException implements Exception {
  final SealFailure failure;
  const SealException(this.failure);
  @override
  String toString() => 'SealException(${failure.name})';
}

bool isSealed(List<int> bytes) =>
    bytes.length >= 8 &&
    ascii.decode(bytes.sublist(0, 8), allowInvalid: true) == sealMagic;

final _aes = AesGcm.with256bits();
final _x25519 = X25519();
final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

Future<SecretKey> _passwordKey(
  String password,
  List<int> salt,
  int iterations,
) => Pbkdf2(
  macAlgorithm: Hmac.sha256(),
  iterations: iterations,
  bits: 256,
).deriveKeyFromPassword(password: password, nonce: salt);

List<int> _wrapAad(List<int> publicKey) => [
  ...utf8.encode('handy-seal-key-v1'),
  ...publicKey,
];

class SealKey {
  final int iterations;
  final Uint8List salt, wrapNonce, wrapped, publicKey;
  const SealKey._(
    this.iterations,
    this.salt,
    this.wrapNonce,
    this.wrapped,
    this.publicKey,
  );

  /// A new key for [password]. Slow on purpose (the password derivation).
  static Future<SealKey> create(
    String password, {
    int iterations = sealIterations,
  }) async {
    if (password.isEmpty) throw ArgumentError('Empty password');
    final pair = await _x25519.newKeyPair();
    final private = await pair.extractPrivateKeyBytes();
    final public = (await pair.extractPublicKey()).bytes;
    return _wrap(private, public, password, iterations);
  }

  static Future<SealKey> _wrap(
    List<int> private,
    List<int> public,
    String password,
    int iterations,
  ) async {
    final random = Random.secure();
    final salt = List<int>.generate(16, (_) => random.nextInt(256));
    final key = await _passwordKey(password, salt, iterations);
    final box = await _aes.encrypt(
      private,
      secretKey: key,
      nonce: _aes.newNonce(),
      aad: _wrapAad(public),
    );
    return SealKey._(
      iterations,
      Uint8List.fromList(salt),
      Uint8List.fromList(box.nonce),
      Uint8List.fromList([...box.cipherText, ...box.mac.bytes]),
      Uint8List.fromList(public),
    );
  }

  /// The same key under a new password. Backups made before keep opening
  /// with the password they were made with.
  Future<SealKey> rewrap(String oldPassword, String newPassword) async {
    if (newPassword.isEmpty) throw ArgumentError('Empty password');
    final private = await _unwrap(
      oldPassword,
      iterations,
      salt,
      wrapNonce,
      wrapped,
      publicKey,
    );
    return _wrap(private, publicKey, newPassword, iterations);
  }

  /// Whether [password] opens this key.
  Future<bool> check(String password) async {
    try {
      await _unwrap(password, iterations, salt, wrapNonce, wrapped, publicKey);
      return true;
    } on SealException {
      return false;
    }
  }

  Map<String, Object> toJson() => {
    'version': _version,
    'iterations': iterations,
    'salt': base64.encode(salt),
    'wrapNonce': base64.encode(wrapNonce),
    'wrapped': base64.encode(wrapped),
    'publicKey': base64.encode(publicKey),
  };

  static SealKey fromJson(Map<String, Object?> json) {
    Uint8List bytes(String name, int length) {
      final value = base64.decode(json[name] as String);
      if (value.length != length) throw const FormatException('Bad seal key');
      return value;
    }

    final iterations = json['iterations'];
    if (json['version'] != _version ||
        iterations is! int ||
        iterations < _minIterations ||
        iterations > _maxIterations)
      throw const FormatException('Bad seal key');
    return SealKey._(
      iterations,
      bytes('salt', 16),
      bytes('wrapNonce', 12),
      bytes('wrapped', 48),
      bytes('publicKey', 32),
    );
  }
}

Future<List<int>> _unwrap(
  String password,
  int iterations,
  List<int> salt,
  List<int> wrapNonce,
  List<int> wrapped,
  List<int> publicKey,
) async {
  final key = await _passwordKey(password, salt, iterations);
  final List<int> private;
  try {
    private = await _aes.decrypt(
      SecretBox(
        wrapped.sublist(0, 32),
        nonce: wrapNonce,
        mac: Mac(wrapped.sublist(32)),
      ),
      secretKey: key,
      aad: _wrapAad(publicKey),
    );
  } on SecretBoxAuthenticationError {
    throw const SealException(SealFailure.wrongPassword);
  }
  final derived = await (await _x25519.newKeyPairFromSeed(
    private,
  )).extractPublicKey();
  if (!_same(derived.bytes, publicKey))
    throw const SealException(SealFailure.damaged);
  return private;
}

bool _same(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var d = 0;
  for (var i = 0; i < a.length; i++) {
    d |= a[i] ^ b[i];
  }
  return d == 0;
}

Future<SecretKey> _payloadKey(
  SecretKey shared,
  List<int> ephemeral,
  List<int> recipient,
) => _hkdf.deriveKey(
  secretKey: shared,
  nonce: [...ephemeral, ...recipient],
  info: utf8.encode('handy-seal-v1'),
);

/// Encrypts [plain] for [key]; no password needed.
Future<Uint8List> seal(List<int> plain, SealKey key) async {
  final ephemeral = await _x25519.newKeyPair();
  final ephemeralPublic = (await ephemeral.extractPublicKey()).bytes;
  final shared = await _x25519.sharedSecretKey(
    keyPair: ephemeral,
    remotePublicKey: SimplePublicKey(key.publicKey, type: KeyPairType.x25519),
  );
  final nonce = _aes.newNonce();
  final header = BytesBuilder(copy: false)
    ..add(ascii.encode(sealMagic))
    ..addByte(_version)
    ..add((ByteData(4)..setUint32(0, key.iterations)).buffer.asUint8List())
    ..add(key.salt)
    ..add(key.wrapNonce)
    ..add(key.wrapped)
    ..add(key.publicKey)
    ..add(ephemeralPublic)
    ..add(nonce);
  final head = header.takeBytes();
  final box = await _aes.encrypt(
    plain,
    secretKey: await _payloadKey(shared, ephemeralPublic, key.publicKey),
    nonce: nonce,
    aad: head,
  );
  return (BytesBuilder(copy: false)
        ..add(head)
        ..add(box.cipherText)
        ..add(box.mac.bytes))
      .takeBytes();
}

/// Opens a file made by [seal] with its password.
Future<Uint8List> unseal(List<int> sealed, String password) async {
  if (!isSealed(sealed)) throw const SealException(SealFailure.notSealed);
  if (sealed.length < _headerLength + 16)
    throw const SealException(SealFailure.damaged);
  if (sealed[8] != _version) throw const SealException(SealFailure.unsupported);
  final bytes = sealed is Uint8List ? sealed : Uint8List.fromList(sealed);
  var at = 9;
  List<int> take(int n) => bytes.sublist(at, at += n);
  final iterations = ByteData.sublistView(bytes, at, at += 4).getUint32(0);
  if (iterations < _minIterations || iterations > _maxIterations)
    throw const SealException(SealFailure.damaged);
  final salt = take(16), wrapNonce = take(12), wrapped = take(48);
  final recipient = take(32), ephemeral = take(32), nonce = take(12);
  final private = await _unwrap(
    password,
    iterations,
    salt,
    wrapNonce,
    wrapped,
    recipient,
  );
  final shared = await _x25519.sharedSecretKey(
    keyPair: await _x25519.newKeyPairFromSeed(private),
    remotePublicKey: SimplePublicKey(ephemeral, type: KeyPairType.x25519),
  );
  try {
    return Uint8List.fromList(
      await _aes.decrypt(
        SecretBox(
          bytes.sublist(_headerLength, bytes.length - 16),
          nonce: nonce,
          mac: Mac(bytes.sublist(bytes.length - 16)),
        ),
        secretKey: await _payloadKey(shared, ephemeral, recipient),
        aad: bytes.sublist(0, _headerLength),
      ),
    );
  } on SecretBoxAuthenticationError {
    throw const SealException(SealFailure.damaged);
  }
}
