/// Hàm băm SHA-256 viết thuần Dart.
///
/// Ứng dụng chỉ cần băm mật khẩu để không lưu mật khẩu gốc, nên thay vì phụ
/// thuộc package `crypto` bên ngoài, phần này được cài đặt ngay trong dự án.
/// Thuật toán theo chuẩn FIPS 180-4.
library;

import 'dart:convert';
import 'dart:typed_data';

/// Bảng hằng số K của SHA-256: 64 chữ số đầu tiên của phần thập phân căn bậc
/// ba của 64 số nguyên tố đầu tiên.
const List<int> _k = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
  0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
  0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
  0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
  0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

/// Giá trị băm khởi tạo: 8 chữ số đầu tiên của phần thập phân căn bậc hai của
/// 8 số nguyên tố đầu tiên.
const List<int> _initialHash = [
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
  0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
];

const int _mask32 = 0xFFFFFFFF;

/// Băm chuỗi [input] theo UTF-8 và trả về chuỗi hex 64 ký tự.
String sha256Hex(String input) {
  final message = utf8.encode(input);
  final digest = _sha256(message);
  final buffer = StringBuffer();
  for (final byte in digest) {
    buffer.write(byte.toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

Uint8List _sha256(List<int> message) {
  // Bước đệm: thêm bit 1, các bit 0, rồi độ dài thông điệp 64 bit.
  final bitLength = message.length * 8;
  final padded = <int>[...message, 0x80];

  while (padded.length % 64 != 56) {
    padded.add(0);
  }

  // Độ dài ghi theo kiểu big-endian 64 bit.
  for (var i = 7; i >= 0; i--) {
    padded.add((bitLength >> (i * 8)) & 0xFF);
  }

  final hash = List<int>.from(_initialHash);
  final words = List<int>.filled(64, 0);

  // Xử lý từng khối 512 bit.
  for (var offset = 0; offset < padded.length; offset += 64) {
    for (var i = 0; i < 16; i++) {
      final index = offset + i * 4;
      words[i] = (padded[index] << 24) |
          (padded[index + 1] << 16) |
          (padded[index + 2] << 8) |
          padded[index + 3];
    }

    for (var i = 16; i < 64; i++) {
      final s0 = _rotr(words[i - 15], 7) ^
          _rotr(words[i - 15], 18) ^
          (words[i - 15] >> 3);
      final s1 = _rotr(words[i - 2], 17) ^
          _rotr(words[i - 2], 19) ^
          (words[i - 2] >> 10);
      words[i] = (words[i - 16] + s0 + words[i - 7] + s1) & _mask32;
    }

    var a = hash[0];
    var b = hash[1];
    var c = hash[2];
    var d = hash[3];
    var e = hash[4];
    var f = hash[5];
    var g = hash[6];
    var h = hash[7];

    for (var i = 0; i < 64; i++) {
      final bigS1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final choose = (e & f) ^ (~e & g);
      final temp1 = (h + bigS1 + choose + _k[i] + words[i]) & _mask32;
      final bigS0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final majority = (a & b) ^ (a & c) ^ (b & c);
      final temp2 = (bigS0 + majority) & _mask32;

      h = g;
      g = f;
      f = e;
      e = (d + temp1) & _mask32;
      d = c;
      c = b;
      b = a;
      a = (temp1 + temp2) & _mask32;
    }

    hash[0] = (hash[0] + a) & _mask32;
    hash[1] = (hash[1] + b) & _mask32;
    hash[2] = (hash[2] + c) & _mask32;
    hash[3] = (hash[3] + d) & _mask32;
    hash[4] = (hash[4] + e) & _mask32;
    hash[5] = (hash[5] + f) & _mask32;
    hash[6] = (hash[6] + g) & _mask32;
    hash[7] = (hash[7] + h) & _mask32;
  }

  final result = Uint8List(32);
  for (var i = 0; i < 8; i++) {
    result[i * 4] = (hash[i] >> 24) & 0xFF;
    result[i * 4 + 1] = (hash[i] >> 16) & 0xFF;
    result[i * 4 + 2] = (hash[i] >> 8) & 0xFF;
    result[i * 4 + 3] = hash[i] & 0xFF;
  }
  return result;
}

/// Dịch vòng phải 32 bit.
int _rotr(int value, int amount) {
  return ((value >> amount) | (value << (32 - amount))) & _mask32;
}
