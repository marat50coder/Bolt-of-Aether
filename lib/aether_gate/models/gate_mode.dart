/// Route the gray-flow router commits to for the current install.
enum GateRoute {
  /// Undecided — this is the first launch or the previous decision expired.
  fresh,

  /// Non-organic user with a live partner URL. The WebView shell owns the UI.
  web,

  /// Organic (or attribution-less) user. Hand off to the native game splash.
  native,
}

/// The concrete decision the router hands back to the warmup screen.
sealed class GateDecision {
  const GateDecision();
}

class GateWeb extends GateDecision {
  const GateWeb(this.url);
  final String url;
}

class GateNative extends GateDecision {
  const GateNative();
}

class GateOffline extends GateDecision {
  const GateOffline();
}
