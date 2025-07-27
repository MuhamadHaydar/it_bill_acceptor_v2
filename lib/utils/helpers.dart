import 'dart:typed_data';

class Helpers {
  static int bytesToInt32(Uint8List bytes, int offset) {
    if (offset + 4 > bytes.length) return 0;

    return bytes[offset] |
    (bytes[offset + 1] << 8) |
    (bytes[offset + 2] << 16) |
    (bytes[offset + 3] << 24);
  }

  static int bytesToInt16(Uint8List bytes, int offset) {
    if (offset + 2 > bytes.length) return 0;

    return bytes[offset] | (bytes[offset + 1] << 8);
  }

  static Uint8List int32ToBytes(int value) {
    final bytes = Uint8List(4);
    bytes[0] = value & 0xFF;
    bytes[1] = (value >> 8) & 0xFF;
    bytes[2] = (value >> 16) & 0xFF;
    bytes[3] = (value >> 24) & 0xFF;
    return bytes;
  }

  static Uint8List int16ToBytes(int value) {
    final bytes = Uint8List(2);
    bytes[0] = value & 0xFF;
    bytes[1] = (value >> 8) & 0xFF;
    return bytes;
  }

  static String formatToCurrency(int value) {
    final double currency = value / 100.0;
    return currency.toStringAsFixed(2);
  }

  static String bytesToHex(Uint8List bytes, {int? length}) {
    final len = length ?? bytes.length;
    final buffer = StringBuffer();

    for (int i = 0; i < len && i < bytes.length; i++) {
      if (i > 0) buffer.write(' ');
      buffer.write(bytes[i].toRadixString(16).toUpperCase().padLeft(2, '0'));
    }

    return buffer.toString();
  }

  static String formatDateTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:'
        '${dateTime.minute.toString().padLeft(2, '0')}:'
        '${dateTime.second.toString().padLeft(2, '0')}.'
        '${(dateTime.millisecond ~/ 10).toString().padLeft(2, '0')}';
  }
}