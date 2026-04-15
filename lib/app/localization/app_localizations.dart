import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
  ];

  static AppLocalizations of(BuildContext context) {
    final AppLocalizations? result =
        Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(result != null, 'No AppLocalizations found in context');
    return result!;
  }

  static const Map<String, Map<String, String>> _localizedValues = {
    'en': {
      'appTitle': 'Airsoft App',
      'home': 'Home',
      'fieldFinder': 'Field Finder',
      'events': 'Events',
      'meetups': 'Meet-ups',
      'settings': 'Settings',
      'profile': 'Profile',
      'editProfile': 'Edit Profile',
      'callSign': 'Call Sign',
      'area': 'Area',
      'teamName': 'Team Name',
      'loadout': 'Loadout',
      'instagram': 'Instagram',
      'facebook': 'Facebook',
      'youtube': 'YouTube',
      'save': 'Save',
      'latestNews': 'Latest News',
      'newFields': 'New Fields',
      'newEvents': 'New Events',
      'newMeetups': 'New Meet-ups',
      'teamPosts': 'Team Creation Posts',
      'searchFields': 'Search fields',
      'searchByNameLocationType': 'Search by name, location, or type',
      'map': 'Map',
      'list': 'List',
      'calendar': 'Calendar',
      'createMeetup': 'Create Meet-up',
      'title': 'Title',
      'content': 'Content',
      'date': 'Date',
      'time': 'Time',
      'location': 'Location',
      'fontSize': 'Font Size',
      'theme': 'Theme',
      'lightMode': 'Light',
      'darkMode': 'Dark',
      'downloadUpdates': 'Download internal updates',
      'notificationSettings': 'Notification Settings',
      'privacySettings': 'Privacy Settings',
      'accountSettings': 'Account Settings',
      'language': 'Language',
      'offlineSync': 'Offline data sync',
      'fieldContact': 'Field Contact',
      'website': 'Website',
      'socialProfiles': 'Social Profiles',
      'contacts': 'Contacts',
      'messages': 'Messages',
      'addContact': 'Add Contact',
      'contactRequests': 'Contact Requests',
    },
    'ja': {
      'appTitle': 'エアソフトアプリ',
      'home': 'ホーム',
      'fieldFinder': 'フィールド検索',
      'events': 'イベント',
      'meetups': '交流募集',
      'settings': '設定',
      'profile': 'プロフィール',
      'editProfile': 'プロフィール編集',
      'callSign': 'コールサイン',
      'area': '活動エリア',
      'teamName': 'チーム名',
      'loadout': '装備',
      'instagram': 'インスタグラム',
      'facebook': 'フェイスブック',
      'youtube': 'ユーチューブ',
      'save': '保存',
      'latestNews': '最新ニュース',
      'newFields': '新着フィールド',
      'newEvents': '新着イベント',
      'newMeetups': '新着交流募集',
      'teamPosts': 'チーム募集投稿',
      'searchFields': 'フィールド検索',
      'searchByNameLocationType': '名前、場所、種別で検索',
      'map': '地図',
      'list': '一覧',
      'calendar': 'カレンダー',
      'createMeetup': '交流募集を作成',
      'title': 'タイトル',
      'content': '内容',
      'date': '日付',
      'time': '時間',
      'location': '場所',
      'fontSize': '文字サイズ',
      'theme': 'テーマ',
      'lightMode': 'ライト',
      'darkMode': 'ダーク',
      'downloadUpdates': '内部更新をダウンロード',
      'notificationSettings': '通知設定',
      'privacySettings': 'プライバシー設定',
      'accountSettings': 'アカウント設定',
      'language': '言語',
      'offlineSync': 'オフライン同期',
      'fieldContact': 'フィールド連絡先',
      'website': 'ウェブサイト',
      'socialProfiles': 'SNSプロフィール',
      'contacts': '連絡先',
      'messages': 'メッセージ',
      'addContact': '連絡先追加',
      'contactRequests': 'リクエスト',
    },
  };

  String get _languageCode => locale.languageCode;

  String _text(String key) => _localizedValues[_languageCode]?[key] ?? key;

  String get appTitle => _text('appTitle');
  String get home => _text('home');
  String get fieldFinder => _text('fieldFinder');
  String get events => _text('events');
  String get meetups => _text('meetups');
  String get settings => _text('settings');
  String get profile => _text('profile');
  String get editProfile => _text('editProfile');
  String get callSign => _text('callSign');
  String get area => _text('area');
  String get teamName => _text('teamName');
  String get loadout => _text('loadout');
  String get instagram => _text('instagram');
  String get facebook => _text('facebook');
  String get youtube => _text('youtube');
  String get save => _text('save');
  String get latestNews => _text('latestNews');
  String get newFields => _text('newFields');
  String get newEvents => _text('newEvents');
  String get newMeetups => _text('newMeetups');
  String get teamPosts => _text('teamPosts');
  String get searchFields => _text('searchFields');
  String get searchByNameLocationType => _text('searchByNameLocationType');
  String get map => _text('map');
  String get list => _text('list');
  String get calendar => _text('calendar');
  String get createMeetup => _text('createMeetup');
  String get title => _text('title');
  String get content => _text('content');
  String get date => _text('date');
  String get time => _text('time');
  String get location => _text('location');
  String get fontSize => _text('fontSize');
  String get theme => _text('theme');
  String get lightMode => _text('lightMode');
  String get darkMode => _text('darkMode');
  String get downloadUpdates => _text('downloadUpdates');
  String get notificationSettings => _text('notificationSettings');
  String get privacySettings => _text('privacySettings');
  String get accountSettings => _text('accountSettings');
  String get language => _text('language');
  String get offlineSync => _text('offlineSync');
  String get fieldContact => _text('fieldContact');
  String get website => _text('website');
  String get socialProfiles => _text('socialProfiles');
  String get contacts => _text('contacts');
  String get messages => _text('messages');
  String get addContact => _text('addContact');
  String get contactRequests => _text('contactRequests');
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales.any(
        (Locale supported) => supported.languageCode == locale.languageCode,
      );

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
