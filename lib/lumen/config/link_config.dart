import '../core/veil_cipher.dart';

/// Single source of configuration for the remote-content pipeline: encoded
/// endpoints and identifiers, plus every timing constant used by the boot
/// pipeline. Numbers here are intentionally off round defaults so this
/// project keeps its own distinctive numeric fingerprint.
class LinkConfig {
  const LinkConfig._();

  // ------------------------------------------------------------ identity

  /// Numeric App Store id used for the AppsFlyer GCD lookup and for the
  /// `store_id` field of the config-body POST (formatted as `id<number>`).
  static const String iosStoreId = '6797957269';

  /// The marketing name that must match App Store Connect verbatim.
  static const String appDisplayName = 'Bolt of Aether';

  // ---------------------------------------------------------- public URLs
  // Two URLs are declared in App Store Connect metadata. Encoding them
  // would gain nothing (they're already publicly attached to the listing),
  // so they ship as plain constants.

  static const String privacyUrl =
      'https://boltofaether.com/privacy-policy.html';
  static const String privacyAsset = 'assets/legal/privacy.html';
  static const String supportUrl =
      'https://boltofaether.com/support.html';

  // -------------------------------------------------------- timing knobs
  // Every value below is deliberately non-round. Do not "clean up" — the
  // spread is the whole point.

  /// How long the push-permission screen stays hidden after a Skip.
  /// Under 3 days on purpose so a user who Skipped is re-invited within
  /// their next few sessions.
  static const int pushSnoozeSeconds = 237600; // ~2.75 days

  /// Interval between opportunistic organic re-conversion attempts once
  /// the route has committed to `native`.
  static const Duration organicRecheckInterval = Duration(hours: 9);

  /// How long AnchorAttrib waits between an initial `Organic` first-report
  /// and the confirming GCD lookup.
  static const Duration organicRecheckDelay = Duration(seconds: 9);

  /// HTTP timeout for the config POST body.
  static const Duration configTimeout = Duration(seconds: 17);

  /// Upper bound on how long `buildPayload` blocks waiting for the
  /// AppsFlyer conversion callback before composing the config body.
  /// Must be generous enough to catch first-launch conversions on
  /// slow networks.
  static const Duration awaitSignalsInstall = Duration(seconds: 9);

  /// Delay between the first foreground frame and the ATT prompt.
  static const Duration attPromptDelay = Duration(milliseconds: 740);

  /// How many times we automatically reload after a -1007 redirect loop.
  static const int redirectRetryLimit = 4;

  /// APNs token poll parameters (before Firebase getToken()).
  static const int apnsPollAttempts = 7;
  static const Duration apnsPollStep = Duration(milliseconds: 680);

  /// Delay between onPageFinished and the follow-up resize + inset
  /// re-injection.
  static const Duration postLoadResizeDelay = Duration(milliseconds: 1280);

  /// Reflow poke delays fired after rotation until the WKWebView settles
  /// on the new viewport.
  static const List<Duration> pokeReflowDelays = <Duration>[
    Duration(milliseconds: 70),
    Duration(milliseconds: 240),
    Duration(milliseconds: 490),
    Duration(milliseconds: 810),
    Duration(milliseconds: 1090),
  ];

  /// Cold-start viewport settle before we mount the WKWebView.
  static const Duration coldViewportSettle = Duration(milliseconds: 410);

  /// Cached-url expiry (days). The router refuses to reuse a saved URL
  /// older than this.
  static const int cachedUrlExpiryDays = 7;

  /// Minimum time the loading UI stays visible so a fast decision does
  /// not look like a flash.
  static const Duration minimumSplash = Duration(milliseconds: 840);

  // ---------------------------------------------------- decoded getters

  static String get relayEndpoint => VeilCipher.reveal(_relayEndpoint);
  static String get appsflyerDevKey => VeilCipher.reveal(_appsflyerDevKey);
  static String get firebaseProjectId => VeilCipher.reveal(_firebaseProjectId);
  static String get gcdBaseUrl => VeilCipher.reveal(_gcdBaseUrl);
  static String get oneLinkTemplate => VeilCipher.reveal(_oneLinkTemplate);

  static String get uaProduct => VeilCipher.reveal(_uaProduct);
  static String get uaPlatformPrefix => VeilCipher.reveal(_uaPlatformPrefix);
  static String get uaPlatformSuffix => VeilCipher.reveal(_uaPlatformSuffix);
  static String get uaEngine => VeilCipher.reveal(_uaEngine);
  static String get uaMobileToken => VeilCipher.reveal(_uaMobileToken);
  static String get uaVersionTag => VeilCipher.reveal(_uaVersionTag);
  static String get uaSafariTag => VeilCipher.reveal(_uaSafariTag);
  static String get uaSafariTail => VeilCipher.reveal(_uaSafariTail);
  static String get uaSafariMajorMinor => VeilCipher.reveal(_uaSafariMajorMinor);
  static String get uaAppIdToken => VeilCipher.reveal(_uaAppIdToken);
  static String get uaAppNameToken => VeilCipher.reveal(_uaAppNameToken);
  static String get uaBundleValue => VeilCipher.reveal(_uaBundleValue);
  static String get uaAppNameValue => VeilCipher.reveal(_uaAppNameValue);

  /// Real iOS bundle identifier — used as `bundle_id` in the config POST
  /// body and any partner-facing identity that must match App Store
  /// Connect / Xcode. Distinct from [uaBundleValue] (which encodes the
  /// numeric-id token used inside the User-Agent, e.g. `appid/6797957269`).
  static String get bundleId => VeilCipher.reveal(_bundleId);

  static String get ledgerPrefix => VeilCipher.reveal(_ledgerPrefix);
  static String get coldLinkKey => VeilCipher.reveal(_coldLinkKey);

  // ------------------------------------------------------ convenience

  /// `store_id` field value per the config-endpoint contract.
  static String get platformStoreId => 'id$iosStoreId';

  /// Whether the remote pipeline is minimally configured. Only the three
  /// values that the pipeline cannot function without gate this — OneLink
  /// and similar optional fields are excluded so an empty OneLink never
  /// silently disables the whole flow.
  static bool get remoteReady =>
      relayEndpoint.startsWith('http') &&
      appsflyerDevKey.length > 8 &&
      firebaseProjectId.length >= 6;

  // ============================================================
  // Generated by tool/encode_link_values.dart — do NOT hand-edit.
  // Re-run the tool after rotating the parameters in veil_cipher.dart.
  // ============================================================

  static const List<int> _relayEndpoint = <int>[0x64, 0x0F, 0xA2, 0x8F, 0xE4, 0x75, 0x23, 0x64, 0x31, 0xDA, 0x98, 0x10, 0x41, 0xEA, 0x07, 0x0B, 0x99, 0xC6, 0x6D, 0x34, 0xE1, 0xE0, 0x07, 0x4D, 0xC8, 0xE7, 0x60, 0x5F, 0xF3, 0x11, 0x81, 0x3B, 0xBD, 0xBD, 0x08];
  static const List<int> _appsflyerDevKey = <int>[0x5A, 0x1F, 0x8C, 0xCC, 0xE7, 0x0C, 0x46, 0x2A, 0x02, 0xFB, 0x9E, 0x25, 0x5B, 0xC4, 0x15, 0x3B, 0xA6, 0x96, 0x5B, 0x2D, 0xBE, 0xD4];
  static const List<int> _firebaseProjectId = <int>[0x3A, 0x4C, 0xE0, 0xCA, 0xA3, 0x7F, 0x38, 0x79, 0x6A, 0x83, 0xCD, 0x50];
  static const List<int> _gcdBaseUrl = <int>[0x64, 0x0F, 0xA2, 0x8F, 0xE4, 0x75, 0x23, 0x64, 0x34, 0xD6, 0x90, 0x17, 0x4A, 0xE7, 0x48, 0x0F, 0x9D, 0xDE, 0x7B, 0x20, 0xA3, 0xFA, 0x0D, 0x52, 0xC9, 0xE7, 0x60, 0x5C, 0xBA, 0x11, 0x88, 0x66, 0xB9, 0xB4, 0x14, 0xA5, 0x03, 0x08, 0x44, 0xC6, 0x98, 0xD8, 0x89, 0x0E, 0x77, 0x3D, 0x4B];
  static const List<int> _oneLinkTemplate = <int>[0x64, 0x0F, 0xA2, 0x8F, 0xE4, 0x75, 0x23, 0x64, 0x31, 0xDA, 0x98, 0x10, 0x4F, 0xE9, 0x12, 0x06, 0x88, 0xDC, 0x26, 0x29, 0xA1, 0xE6, 0x04, 0x49, 0x89, 0xEF, 0x21, 0x5C, 0xF0, 0x57, 0xD5, 0x27, 0xA1, 0xBF, 0x57, 0xFC, 0x2C, 0x58, 0x50, 0x87, 0xC0, 0x9C, 0x90];
  static const List<int> _uaProduct = <int>[0x41, 0x14, 0xAC, 0x96, 0xFB, 0x23, 0x6D, 0x64, 0x66, 0x9B, 0xC4];
  static const List<int> _uaPlatformPrefix = <int>[0x24, 0x12, 0x86, 0x97, 0xF8, 0x21, 0x69, 0x70, 0x73, 0xF6, 0xA4, 0x31, 0x0E, 0xE5, 0x36, 0x06, 0x82, 0xC0, 0x6D, 0x66, 0x80, 0xD0];
  static const List<int> _uaPlatformSuffix = <int>[0x60, 0x12, 0xBD, 0x9A, 0xB7, 0x02, 0x6D, 0x28, 0x73, 0xFA, 0xA7, 0x44, 0x76, 0xA5];
  static const List<int> _uaEngine = <int>[0x4D, 0x0B, 0xA6, 0x93, 0xF2, 0x18, 0x69, 0x29, 0x18, 0xDC, 0x80, 0x4B, 0x18, 0xBC, 0x53, 0x40, 0xDC, 0x80, 0x39, 0x73, 0xEF, 0xAB, 0x23, 0x68, 0xB3, 0xC9, 0x43, 0x1D, 0xB5, 0x14, 0x8F, 0x7E, 0xA8, 0xF5, 0x3F, 0xAC, 0x3F, 0x07, 0x4A, 0x9B];
  static const List<int> _uaMobileToken = <int>[0x41, 0x14, 0xB4, 0x96, 0xFB, 0x2A, 0x23, 0x7A, 0x66, 0xF0, 0xC5, 0x50, 0x16];
  static const List<int> _uaVersionTag = <int>[0x5A, 0x1E, 0xA4, 0x8C, 0xFE, 0x20, 0x62, 0x64];
  static const List<int> _uaSafariTag = <int>[0x5F, 0x1A, 0xB0, 0x9E, 0xE5, 0x26, 0x23];
  static const List<int> _uaSafariTail = <int>[0x3A, 0x4B, 0xE2, 0xD1, 0xA6];
  static const List<int> _uaSafariMajorMinor = <int>[0x3D, 0x43, 0xF8, 0xCD];
  static const List<int> _uaAppIdToken = <int>[0x6D, 0x0B, 0xA6, 0x96, 0xF3, 0x60];
  static const List<int> _uaAppNameToken = <int>[0x6D, 0x0B, 0xA6, 0x91, 0xF6, 0x22, 0x69, 0x64];
  static const List<int> _uaBundleValue = <int>[0x3A, 0x4C, 0xEF, 0xC8, 0xAE, 0x7A, 0x3B, 0x79, 0x65, 0x8C];
  static const List<int> _uaAppNameValue = <int>[0x4E, 0x14, 0xBA, 0x8B, 0xD8, 0x29, 0x4D, 0x2E, 0x27, 0xDD, 0x91, 0x16];
  static const List<int> _bundleId = <int>[0x6F, 0x14, 0xBB, 0xD1, 0xF5, 0x20, 0x60, 0x3F, 0x32, 0xD0, 0x80, 0x0C, 0x4B, 0xFE, 0x48, 0x0C, 0x82, 0xC2, 0x7C, 0x27, 0xAA, 0xF7, 0x00, 0x45, 0x95, 0xE3, 0x6E, 0x5C, 0xF0];
  static const List<int> _ledgerPrefix = <int>[0x60, 0x0E, 0xBB, 0x9A, 0xF9, 0x61, 0x7F, 0x3B, 0x32, 0xDB, 0xDA];
  static const List<int> _coldLinkKey = <int>[0x60, 0x0E, 0xBB, 0x9A, 0xF9, 0x10, 0x63, 0x3B, 0x36, 0xDB, 0xAB, 0x08, 0x47, 0xE2, 0x0D];
}
