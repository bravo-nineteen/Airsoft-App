import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class LocationPreferences {
  static const String allCountries = 'All countries';
  static const List<String> countries = <String>[
    allCountries,
    'Japan',
    'United States',
    'United Kingdom',
    'Australia',
    'Canada',
    'Germany',
    'France',
    'South Korea',
    'Singapore',
    'Thailand',
    'Philippines',
    'Taiwan',
    'Other',
  ];

  static const List<String> japanPrefectures = <String>[
    'Hokkaido',
    'Aomori',
    'Iwate',
    'Miyagi',
    'Akita',
    'Yamagata',
    'Fukushima',
    'Ibaraki',
    'Tochigi',
    'Gunma',
    'Saitama',
    'Chiba',
    'Tokyo',
    'Kanagawa',
    'Niigata',
    'Toyama',
    'Ishikawa',
    'Fukui',
    'Yamanashi',
    'Nagano',
    'Gifu',
    'Shizuoka',
    'Aichi',
    'Mie',
    'Shiga',
    'Kyoto',
    'Osaka',
    'Hyogo',
    'Nara',
    'Wakayama',
    'Tottori',
    'Shimane',
    'Okayama',
    'Hiroshima',
    'Yamaguchi',
    'Tokushima',
    'Kagawa',
    'Ehime',
    'Kochi',
    'Fukuoka',
    'Saga',
    'Nagasaki',
    'Kumamoto',
    'Oita',
    'Miyazaki',
    'Kagoshima',
    'Okinawa',
  ];

  static String _countryKeyForUser() {
    final String uid =
        Supabase.instance.client.auth.currentUser?.id ?? 'anonymous';
    return 'preferred-country-$uid';
  }

  static Future<String> loadPreferredCountry() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(_countryKeyForUser()) ?? allCountries;
  }

  static Future<void> savePreferredCountry(String country) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_countryKeyForUser(), country);
  }

  static bool matchesCountry({
    required String selectedCountry,
    String? country,
    String? prefecture,
    String? location,
    String? address,
  }) {
    if (selectedCountry == allCountries) {
      return true;
    }

    final String normalizedCountry = (country ?? '').trim().toLowerCase();
    final String normalizedPrefecture = (prefecture ?? '').trim().toLowerCase();
    final String haystack = <String>[
      country ?? '',
      prefecture ?? '',
      location ?? '',
      address ?? '',
    ].join(' ').toLowerCase();

    if (selectedCountry == 'Japan') {
      if (normalizedCountry == 'japan' || haystack.contains('japan') || haystack.contains('日本')) {
        return true;
      }
      if (japanPrefectures.any((String p) => p.toLowerCase() == normalizedPrefecture)) {
        return true;
      }
      return japanPrefectures.any((String p) => haystack.contains(p.toLowerCase()));
    }

    final String target = selectedCountry.toLowerCase();
    if (normalizedCountry == target) {
      return true;
    }
    return haystack.contains(target);
  }
}
