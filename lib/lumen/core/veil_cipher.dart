import 'dart:convert';
import 'dart:typed_data';

/// Stream codec: ANSI-C LCG keystream XORed with the payload and with the
/// byte index, so the transform is not a plain repeating PRNG. Rotate the
/// parameters and re-run `tool/encode_link_values.dart` to refresh every
/// array in the config file.
class VeilCipher {
  const VeilCipher._();

  static const int _seed = 0x4A91E2C7;
  static const int _mul = 1103515245;
  static const int _add = 12345;
  static const int _mask = 0xFFFFFFFF;
  static const int _shift = 11;

  static String reveal(List<int> encoded) => utf8.decode(_stream(encoded));

  static List<int> conceal(String plain) => _stream(utf8.encode(plain));

  static Uint8List _stream(List<int> data) {
    final out = Uint8List(data.length);
    var state = _seed;
    for (var i = 0; i < data.length; i++) {
      state = (state * _mul + _add) & _mask;
      out[i] = data[i] ^ ((state >> _shift) & 0xff) ^ (i & 0xff);
    }
    return out;
  }
}
