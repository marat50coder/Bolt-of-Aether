import 'dart:convert';
import 'dart:typed_data';

/// PRNG-keystream XOR codec. A 32-bit linear-congruential generator seeded
/// from a per-project constant produces a pseudo-random byte keystream that
/// is XORed against the payload. Rotate the parameters below (and re-run
/// `tool/encode_link_values.dart`) to regenerate every byte-array constant
/// in [../config/link_config.dart].
///
/// The runtime intentionally exposes both directions of the transform: an
/// integrity self-test can call [conceal] to reproduce any array byte-for
/// byte and assert against the shipped constants. The application only
/// ever calls [reveal] at runtime.
class VeilCipher {
  const VeilCipher._();

  static const int _seed = 0x9C7B4E31;
  static const int _mul = 214013;
  static const int _add = 2531011;
  static const int _mask = 0xFFFFFFFF;
  static const int _shift = 8;

  static String reveal(List<int> encoded) => utf8.decode(_stream(encoded));

  static List<int> conceal(String plain) => _stream(utf8.encode(plain));

  static Uint8List _stream(List<int> data) {
    final out = Uint8List(data.length);
    var state = _seed;
    for (var i = 0; i < data.length; i++) {
      state = (state * _mul + _add) & _mask;
      out[i] = data[i] ^ ((state >> _shift) & 0xff);
    }
    return out;
  }
}
