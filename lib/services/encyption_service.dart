import 'dart:typed_data';
import 'dart:math';
import '../models/ssp_command.dart';

class EncryptionService {
  static void initiateSSPHostKeys(SSPKeys keys, SSPCommand cmd) {
    final random = Random.secure();

    // Generate cryptographic values
    keys.generator = _generatePrime();
    keys.modulus = _generatePrime();
    keys.hostInter = random.nextInt(0x7FFFFFFF) + 1;
  }

  static void createSSPHostEncryptionKey(SSPKeys keys) {
    // Simplified key derivation - in production, use proper cryptographic methods
    keys.keyHost = _modPow(keys.slaveInterKey, keys.hostInter, keys.modulus);
  }

  static Uint8List encryptData(Uint8List data, SSPKeys keys) {
    if (data.isEmpty) return data;

    final encrypted = Uint8List(data.length);
    int keyIndex = 0;
    final keyBytes = _intToBytes(keys.keyHost ^ keys.fixedKey);

    for (int i = 0; i < data.length; i++) {
      encrypted[i] = data[i] ^ keyBytes[keyIndex % keyBytes.length];
      keyIndex++;
    }

    return encrypted;
  }

  static Uint8List decryptData(Uint8List data, SSPKeys keys) {
    // XOR encryption is symmetric
    return encryptData(data, keys);
  }

  static int _generatePrime() {
    final random = Random.secure();
    int candidate;

    do {
      candidate = random.nextInt(0x7FFFFFFF) + 1000;
    } while (!_isPrime(candidate));

    return candidate;
  }

  static bool _isPrime(int n) {
    if (n < 2) return false;
    if (n == 2) return true;
    if (n % 2 == 0) return false;

    for (int i = 3; i * i <= n; i += 2) {
      if (n % i == 0) return false;
    }
    return true;
  }

  static int _modPow(int base, int exponent, int modulus) {
    if (modulus == 1) return 0;

    int result = 1;
    base = base % modulus;

    while (exponent > 0) {
      if (exponent % 2 == 1) {
        result = (result * base) % modulus;
      }
      exponent = exponent >> 1;
      base = (base * base) % modulus;
    }

    return result;
  }

  static Uint8List _intToBytes(int value) {
    final bytes = Uint8List(8);
    for (int i = 0; i < 8; i++) {
      bytes[i] = (value >> (i * 8)) & 0xFF;
    }
    return bytes;
  }
}