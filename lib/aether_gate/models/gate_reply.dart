/// The parsed response from the config endpoint.
class GateReply {
  const GateReply({
    required this.granted,
    this.destination,
    this.expiresAt,
    this.message,
  });

  /// `true` when the backend authorises the WebView path with a live URL.
  final bool granted;

  /// The URL to load, present only when [granted] is true.
  final String? destination;

  /// Optional absolute UNIX timestamp (seconds) after which the saved URL
  /// must not be reused. Falls back to [AetherRelayConfig.savedUrlExpiryDays]
  /// when the backend omits it.
  final int? expiresAt;

  final String? message;

  factory GateReply.parse(Map<String, dynamic> body) {
    final ok = body['ok'] == true;
    final url = body['url'];
    final expires = body['expires'];
    return GateReply(
      granted: ok && url is String && url.isNotEmpty,
      destination: url is String ? url : null,
      expiresAt: expires is int
          ? expires
          : (expires is String ? int.tryParse(expires) : null),
      message: body['message'] is String ? body['message'] as String : null,
    );
  }

  static const GateReply denied = GateReply(granted: false);
}
