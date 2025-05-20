import 'package:encrypt/encrypt.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

class CryptoUtils {
  static String encryptData(String data, String key) {
    final encrypter = Encrypter(AES(Key.fromUtf8(key), mode: AESMode.cbc));
    final iv = IV
        .fromLength(16); // Fixed IV for simplicity; use random IV in production
    final encrypted = encrypter.encrypt(data, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  static String decryptData(String encryptedData, String key) {
    final parts = encryptedData.split(':');
    if (parts.length != 2) throw Exception('Invalid encrypted data format');
    final iv = IV.fromBase64(parts[0]);
    final encrypted = Encrypted.fromBase64(parts[1]);
    final encrypter = Encrypter(AES(Key.fromUtf8(key), mode: AESMode.cbc));
    return encrypter.decrypt(encrypted, iv: iv);
  }

  static String generatePSK(
      String learnerId, String teacherId, String classId) {
    final input = '$learnerId:$teacherId:$classId';
    return sha256.convert(utf8.encode(input)).toString().substring(0, 32);
  }
}
