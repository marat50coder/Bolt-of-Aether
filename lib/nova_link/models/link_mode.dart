/// Persisted routing choice for the current install.
enum LinkRoute {
  /// Undecided — first launch, or a previous decision has expired.
  fresh,

  /// Non-organic install with a live partner URL. WebView owns the UI.
  web,

  /// Organic (or attribution-less) install. Fall through to the native app.
  native,
}

/// Result the router hands back to the boot screen.
sealed class LinkDecision {
  const LinkDecision();
}

class LinkWeb extends LinkDecision {
  const LinkWeb(this.url);
  final String url;

  @override
  String toString() => 'LinkWeb($url)';
}

class LinkNative extends LinkDecision {
  const LinkNative();

  @override
  String toString() => 'LinkNative';
}

class LinkOffline extends LinkDecision {
  const LinkOffline();

  @override
  String toString() => 'LinkOffline';
}
