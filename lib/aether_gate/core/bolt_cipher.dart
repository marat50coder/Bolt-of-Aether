import 'dart:convert';
import 'dart:typed_data';

/// Keystream XOR codec. A 32-bit linear-congruential generator, seeded from a
/// per-project constant, produces a pseudo-random byte keystream that is XORed
/// against the payload: `plain[i] = enc[i] ^ ((advance(state_i) >> 16) & 0xff)`.
///
/// This is a PRNG-keystream family — a deliberately different data-flow shape
/// than a table / position lookup or a stream-cipher key schedule, so it shares
/// no machine code with sibling projects. Rotate `_lcgSeed` (and re-run
/// `tool/encode_relay_values.dart`) to regenerate every encoded array; the tool
/// prints a VERIFY block so the round-trip is proved before shipping.
class BoltCipher {
  const BoltCipher._();

  // Project-unique seed + a classic 32-bit LCG (Numerical Recipes constants).
  static const int _lcgSeed = 0x5F3AC91D;
  static const int _lcgMul = 1664525;
  static const int _lcgAdd = 1013904223;
  static const int _word = 0xFFFFFFFF;

  /// Decode a byte array previously produced by the encode tool.
  static String reveal(List<int> encoded) => utf8.decode(_stream(encoded));

  /// The inverse — XOR is symmetric, so encode and decode share one path. Kept
  /// in the runtime lib so an integrity test can call it; the shipping app
  /// never encodes anything at runtime.
  static List<int> conceal(String plain) => _stream(utf8.encode(plain));

  static Uint8List _stream(List<int> data) {
    final out = Uint8List(data.length);
    var state = _lcgSeed;
    for (var i = 0; i < data.length; i++) {
      state = (state * _lcgMul + _lcgAdd) & _word;
      out[i] = data[i] ^ ((state >> 16) & 0xff);
    }
    return out;
  }
}
