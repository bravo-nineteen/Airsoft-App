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

  // ── Per-country region lists ────────────────────────────────────────────────

  static const List<String> usStates = <String>[
    'Alabama', 'Alaska', 'Arizona', 'Arkansas', 'California', 'Colorado',
    'Connecticut', 'Delaware', 'Florida', 'Georgia', 'Hawaii', 'Idaho',
    'Illinois', 'Indiana', 'Iowa', 'Kansas', 'Kentucky', 'Louisiana', 'Maine',
    'Maryland', 'Massachusetts', 'Michigan', 'Minnesota', 'Mississippi',
    'Missouri', 'Montana', 'Nebraska', 'Nevada', 'New Hampshire', 'New Jersey',
    'New Mexico', 'New York', 'North Carolina', 'North Dakota', 'Ohio',
    'Oklahoma', 'Oregon', 'Pennsylvania', 'Rhode Island', 'South Carolina',
    'South Dakota', 'Tennessee', 'Texas', 'Utah', 'Vermont', 'Virginia',
    'Washington', 'West Virginia', 'Wisconsin', 'Wyoming',
  ];

  static const List<String> ukRegions = <String>[
    'England', 'Scotland', 'Wales', 'Northern Ireland',
    'East Midlands', 'East of England', 'London', 'North East', 'North West',
    'South East', 'South West', 'West Midlands', 'Yorkshire and the Humber',
    'Central Belt', 'Highlands', 'Lowlands',
  ];

  static const List<String> australiaStates = <String>[
    'New South Wales', 'Victoria', 'Queensland', 'South Australia',
    'Western Australia', 'Tasmania', 'Australian Capital Territory',
    'Northern Territory',
  ];

  static const List<String> canadaProvinces = <String>[
    'Alberta', 'British Columbia', 'Manitoba', 'New Brunswick',
    'Newfoundland and Labrador', 'Northwest Territories', 'Nova Scotia',
    'Nunavut', 'Ontario', 'Prince Edward Island', 'Quebec', 'Saskatchewan',
    'Yukon',
  ];

  static const List<String> germanyStates = <String>[
    'Baden-Württemberg', 'Bavaria', 'Berlin', 'Brandenburg', 'Bremen',
    'Hamburg', 'Hesse', 'Lower Saxony', 'Mecklenburg-Vorpommern',
    'North Rhine-Westphalia', 'Rhineland-Palatinate', 'Saarland', 'Saxony',
    'Saxony-Anhalt', 'Schleswig-Holstein', 'Thuringia',
  ];

  static const List<String> franceRegions = <String>[
    'Auvergne-Rhône-Alpes', 'Bourgogne-Franche-Comté', 'Brittany',
    'Centre-Val de Loire', 'Corsica', 'Grand Est', 'Hauts-de-France',
    'Île-de-France', 'Normandy', 'Nouvelle-Aquitaine', 'Occitanie',
    'Pays de la Loire', "Provence-Alpes-Côte d'Azur",
  ];

  static const List<String> southKoreaRegions = <String>[
    'Seoul', 'Busan', 'Daegu', 'Incheon', 'Gwangju', 'Daejeon', 'Ulsan',
    'Sejong', 'Gyeonggi', 'Gangwon', 'North Chungcheong', 'South Chungcheong',
    'North Jeolla', 'South Jeolla', 'North Gyeongsang', 'South Gyeongsang',
    'Jeju',
  ];

  static const List<String> philippinesRegions = <String>[
    'NCR (Metro Manila)', 'CAR', 'Ilocos Region', 'Cagayan Valley',
    'Central Luzon', 'CALABARZON', 'MIMAROPA', 'Bicol Region',
    'Western Visayas', 'Central Visayas', 'Eastern Visayas',
    'Zamboanga Peninsula', 'Northern Mindanao', 'Davao Region', 'SOCCSKSARGEN',
    'Caraga', 'BARMM',
  ];

  static const List<String> taiwanDivisions = <String>[
    'Taipei', 'New Taipei', 'Taoyuan', 'Taichung', 'Tainan', 'Kaohsiung',
    'Keelung', 'Hsinchu City', 'Chiayi City',
    'Hsinchu County', 'Miaoli', 'Changhua', 'Nantou', 'Yunlin',
    'Chiayi County', 'Pingtung', 'Yilan', 'Hualien', 'Taitung',
    'Penghu', 'Kinmen', 'Lienchiang',
  ];

  static const List<String> thailandProvinces = <String>[
    'Bangkok', 'Chiang Mai', 'Chiang Rai', 'Phuket', 'Krabi',
    'Koh Samui (Surat Thani)', 'Pattaya (Chonburi)', 'Ayutthaya',
    'Nakhon Ratchasima', 'Khon Kaen', 'Udon Thani', 'Chiang Rai',
    'Nonthaburi', 'Pathum Thani', 'Samut Prakan', 'Rayong',
  ];

  static const List<String> singaporeRegions = <String>[
    'Central Region', 'East Region', 'North Region',
    'North-East Region', 'West Region',
  ];

  /// Returns the predefined region/state/prefecture list for a given country.
  /// Returns an empty list for unknown countries or those with no predefined list.
  static List<String> getRegions(String country) {
    switch (country) {
      case 'Japan':          return japanPrefectures;
      case 'United States':  return usStates;
      case 'United Kingdom': return ukRegions;
      case 'Australia':      return australiaStates;
      case 'Canada':         return canadaProvinces;
      case 'Germany':        return germanyStates;
      case 'France':         return franceRegions;
      case 'South Korea':    return southKoreaRegions;
      case 'Philippines':    return philippinesRegions;
      case 'Taiwan':         return taiwanDivisions;
      case 'Thailand':       return thailandProvinces;
      case 'Singapore':      return singaporeRegions;
      default:               return const <String>[];
    }
  }

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
