import 'dart:io';

class AdConfig {
  const AdConfig._();

  static const int feedAdFrequency = 4;

  static String? get bannerAdUnitId {
    if (Platform.isAndroid) {
      return _nonEmpty(
        const String.fromEnvironment('ADMOB_BANNER_ANDROID'),
      );
    }
    if (Platform.isIOS) {
      return _nonEmpty(const String.fromEnvironment('ADMOB_BANNER_IOS'));
    }
    return null;
  }

  static bool get isConfigured => bannerAdUnitId != null;

  static String? _nonEmpty(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }
}
