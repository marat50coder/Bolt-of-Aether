/// Parsed response from the config endpoint.
class LinkReply {
  const LinkReply({
    required this.granted,
    this.destination,
    this.expiresAt,
    this.message,
  });

  /// True when the backend authorises the WebView path with a live URL.
  final bool granted;

  /// The URL to load, present only when [granted] is true.
  final String? destination;

  /// Optional absolute UNIX timestamp (seconds) after which the cached URL
  /// must not be reused. When absent the ledger falls back to the project
  /// default expiry from `LinkConfig.cachedUrlExpiryDays`.
  final int? expiresAt;

  /// Backend-supplied message (typically the "no data" body for organic
  /// installs). Its presence marks a real HTTP answer as opposed to a
  /// transport error.
  final String? message;

  factory LinkReply.parse(Map<String, dynamic> body) {
    final ok = body['ok'] == true;
    final url = body['url'];
    final expires = body['expires'];
    return LinkReply(
      granted: ok && url is String && url.isNotEmpty,
      destination: url is String ? url : null,
      expiresAt: expires is int
          ? expires
          : (expires is String ? int.tryParse(expires) : null),
      message: body['message'] is String ? body['message'] as String : null,
    );
  }

  static const LinkReply denied = LinkReply(granted: false);
}
