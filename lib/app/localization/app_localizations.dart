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
      'system': 'System',
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
      'add': 'Add',
      'descriptionRequired': 'Description is required.',
      'profileAccountDetails': 'Call sign, avatar, and account details',
      'manageContactsRequests': 'Manage your contacts and requests',
      'subscription': 'Subscription',
      'free': 'Free',
        'english': 'English',
        'japanese': 'Japanese',
        'email': 'Email',
        'password': 'Password',
        'login': 'Login',
        'signUp': 'Sign Up',
        'createAccount': 'Create account',
        'signupSuccess': 'Signup successful. You can now log in.',
        'signupFailed': 'Signup failed: {error}',
        'createPost': 'Create Post',
        'section': 'Section',
        'body': 'Body',
        'bodyLinkHint': 'Links like https://example.com will be clickable.',
        'publish': 'Publish',
        'uploading': 'Uploading...',
        'addImage': 'Add Image',
        'titleRequired': 'Title is required.',
        'bodyRequired': 'Body is required.',
        'failedUploadImage': 'Failed to upload image: {error}',
        'failedCreatePost': 'Failed to create post: {error}',
        'searchPosts': 'Search posts',
        'post': 'Post',
        'noPostsFound': 'No posts found.',
        'failedLoadBoard': 'Failed to load board:\n{error}',
        'comments': 'Comments',
        'noCommentsYet': 'No comments yet.',
        'writeComment': 'Write a comment',
        'failedSendComment': 'Failed to send comment: {error}',
        'justNow': 'Just now',
        'now': 'Now',
        'minutesAgoShort': '{value}m ago',
        'hoursAgoShort': '{value}h ago',
        'daysAgoShort': '{value}d ago',
        'minutesShort': '{value}m',
        'hoursShort': '{value}h',
        'daysShort': '{value}d',
        'all': 'All',
        'meetupsLabel': 'Meetups',
        'techTalk': 'Tech Talk',
        'troubleshooting': 'Troubleshooting',
        'offTopic': 'Off-topic',
        'memes': 'Memes',
        'buySell': 'Buy / Sell',
        'gearShowcase': 'Gear Showcase',
        'fieldTalk': 'Field Talk',
        'createEvent': 'Create Event',
        'event': 'Event',
        'eventType': 'Event Type',
        'skillLevel': 'Skill Level',
        'locationField': 'Location / Field',
        'prefecture': 'Prefecture',
        'start': 'Start',
        'end': 'End',
        'change': 'Change',
        'priceJpy': 'Price (JPY)',
        'maxPlayers': 'Max Players',
        'organizerName': 'Organizer Name',
        'contactInfo': 'Contact Info',
        'contactInfoHint': 'Email, Instagram, LINE, etc.',
        'description': 'Description',
        'rulesNotes': 'Rules / Notes',
        'saveEvent': 'Save Event',
        'endAfterStart': 'End time must be after start time.',
        'failedCreateEvent': 'Failed to create event: {error}',
        'failedLoadEvents': 'Failed to load events:\n{error}',
        'noEventsFound': 'No events found.',
        'type': 'Type',
        'price': 'Price',
        'organizer': 'Organizer',
        'contact': 'Contact',
        'eventsComingNext': 'Events coming next',
        'findUsers': 'Find Users',
        'noContactsYet': 'No contacts yet.',
        'failedLoadContacts': 'Failed to load contacts:\n{error}',
        'operator': 'Operator',
        'noMessagesYet': 'No messages yet.',
        'failedLoadMessages': 'Failed to load messages:\n{error}',
        'dmOnlyAccepted':
          'Direct messaging is only available for accepted contacts.',
        'writeMessage': 'Write a message',
        'failedSendMessage': 'Failed to send message: {error}',
        'searchUsersHint': 'Search call sign, code, area, team',
        'noUsersFound': 'No users found.',
        'failedLoadUsers': 'Failed to load users:\n{error}',
        'contactRequestSent': 'Contact request sent to {name}.',
        'failedSendRequest': 'Failed to send request: {error}',
        'notifications': 'Notifications',
        'markAllRead': 'Mark all read',
        'noNotificationsYet': 'No notifications yet.',
        'failedLoadNotifications': 'Failed to load notifications:\n{error}',
        'failedLoadNotificationSettings':
          'Failed to load notification settings: {error}',
        'failedSaveNotificationSettings':
          'Failed to save notification settings: {error}',
        'noNotificationSettingsFound': 'No notification settings found.',
        'newEventsLabel': 'New Events',
        'meetupActivity': 'Meetup Activity',
        'directMessages': 'Direct Messages',
        'fieldUpdates': 'Field Updates',
        'newEventsSubtitle': 'Get notified when new events go live',
        'meetupActivitySubtitle': 'Get notified about meetup updates',
        'directMessagesSubtitle': 'Get notified when someone messages you',
        'fieldUpdatesSubtitle': 'Get notified about field changes and news',
        'edit': 'Edit',
        'saveChanges': 'Save changes',
        'failedSaveProfile': 'Failed to save profile: {error}',
        'avatarUpdated': 'Avatar updated.',
        'avatarUpdateFailed': 'Avatar update failed: {error}',
        'updating': 'Updating...',
        'changeAvatar': 'Change Avatar',
        'cropAvatar': 'Crop Avatar',
        'noProfileAvailable': 'No profile available.',
        'profileError': 'Profile error:\n{error}',
        'signedInAccount': 'Signed-in account',
        'display': 'Display',
        'lightDarkControls': 'Light and dark display controls',
        'pushNotifications': 'Push Notifications',
        'manageAlerts': 'Manage event, board, DM, and field alerts',
        'privacy': 'Privacy',
        'privacyControls': 'Privacy Controls',
        'profileVisibilityPermissions':
          'Profile visibility and interaction permissions',
        'blockedUsers': 'Blocked Users',
        'manageBlockedAccounts': 'Manage blocked accounts',
        'account': 'Account',
        'viewSignedInEmail': 'View your signed-in email account',
        'logout': 'Logout',
        'logoutFailed': 'Logout failed: {error}',
        'logoutConfirmMessage': 'Do you want to sign out of your account?',
        'cancel': 'Cancel',
        'displayThemeSubtitle': 'Dark theme currently active',
        'fontSizePlaceholder': 'Font size control placeholder',
        'showAreaProfile': 'Show area on profile',
        'showTeamProfile': 'Show team name on profile',
        'allowDirectMessages': 'Allow direct messages',
        'newEventNotifications': 'New event notifications',
        'meetupActivityNotifications': 'Meet-up activity notifications',
        'directMessageNotifications': 'Direct message notifications',
        'fieldUpdateNotifications': 'Field update notifications',
        'searchFieldsHint': 'Search by field name or location',
        'fieldType': 'Field Type',
        'minRating': 'Min Rating',
        'any': 'Any',
        'noRating': 'No rating',
        'noRatingYet': 'No rating yet',
        'noDescriptionAvailable': 'No description available.',
        'coordinates': 'Coordinates',
        'mapViewPlaceholder': 'Map view placeholder',
        'failedLoadFields': 'Failed to load fields: {error}',
        'noFieldsFound': 'No fields found.',
        'fieldMap': 'Field Map',
        'board': 'Board',
        'fieldOps': 'FieldOps',
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
      'system': 'システム',
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
      'add': '追加',
      'descriptionRequired': '説明は必須です。',
      'profileAccountDetails': 'コールサイン、アバター、アカウント情報',
      'manageContactsRequests': '連絡先とリクエストを管理',
      'subscription': 'サブスクリプション',
      'free': '無料',
      'english': '英語',
      'japanese': '日本語',
      'email': 'メールアドレス',
      'password': 'パスワード',
      'login': 'ログイン',
      'signUp': '新規登録',
      'createAccount': 'アカウント作成',
      'signupSuccess': '登録が完了しました。ログインできます。',
      'signupFailed': '登録に失敗しました: {error}',
      'createPost': '投稿を作成',
      'section': 'セクション',
      'body': '本文',
      'bodyLinkHint': 'https://example.com のようなリンクはタップできます。',
      'publish': '公開',
      'uploading': 'アップロード中...',
      'addImage': '画像を追加',
      'titleRequired': 'タイトルは必須です。',
      'bodyRequired': '本文は必須です。',
      'failedUploadImage': '画像のアップロードに失敗しました: {error}',
      'failedCreatePost': '投稿の作成に失敗しました: {error}',
      'searchPosts': '投稿を検索',
      'post': '投稿',
      'noPostsFound': '投稿が見つかりません。',
      'failedLoadBoard': '掲示板の読み込みに失敗しました:\n{error}',
      'comments': 'コメント',
      'noCommentsYet': 'まだコメントはありません。',
      'writeComment': 'コメントを書く',
      'failedSendComment': 'コメント送信に失敗しました: {error}',
      'justNow': 'たった今',
      'now': '今',
      'minutesAgoShort': '{value}分前',
      'hoursAgoShort': '{value}時間前',
      'daysAgoShort': '{value}日前',
      'minutesShort': '{value}分',
      'hoursShort': '{value}時間',
      'daysShort': '{value}日',
      'all': 'すべて',
      'meetupsLabel': '交流募集',
      'techTalk': '技術トーク',
      'troubleshooting': 'トラブル相談',
      'offTopic': '雑談',
      'memes': 'ミーム',
      'buySell': '売買',
      'gearShowcase': '装備紹介',
      'fieldTalk': 'フィールド雑談',
      'createEvent': 'イベント作成',
      'event': 'イベント',
      'eventType': 'イベント種別',
      'skillLevel': 'レベル',
      'locationField': '場所 / フィールド',
      'prefecture': '都道府県',
      'start': '開始',
      'end': '終了',
      'change': '変更',
      'priceJpy': '料金 (円)',
      'maxPlayers': '最大人数',
      'organizerName': '主催者名',
      'contactInfo': '連絡先',
      'contactInfoHint': 'メール、Instagram、LINE など',
      'description': '説明',
      'rulesNotes': 'ルール / 注意事項',
      'saveEvent': 'イベントを保存',
      'endAfterStart': '終了時刻は開始時刻より後にしてください。',
      'failedCreateEvent': 'イベント作成に失敗しました: {error}',
      'failedLoadEvents': 'イベントの読み込みに失敗しました:\n{error}',
      'noEventsFound': 'イベントが見つかりません。',
      'type': '種別',
      'price': '料金',
      'organizer': '主催',
      'contact': '連絡先',
      'eventsComingNext': 'まもなくイベント機能を公開します',
      'findUsers': 'ユーザー検索',
      'noContactsYet': '連絡先はまだありません。',
      'failedLoadContacts': '連絡先の読み込みに失敗しました:\n{error}',
      'operator': 'オペレーター',
      'noMessagesYet': 'メッセージはまだありません。',
      'failedLoadMessages': 'メッセージの読み込みに失敗しました:\n{error}',
      'dmOnlyAccepted': 'ダイレクトメッセージは承認済み連絡先のみ利用できます。',
      'writeMessage': 'メッセージを書く',
      'failedSendMessage': 'メッセージ送信に失敗しました: {error}',
      'searchUsersHint': 'コールサイン、コード、エリア、チームで検索',
      'noUsersFound': 'ユーザーが見つかりません。',
      'failedLoadUsers': 'ユーザーの読み込みに失敗しました:\n{error}',
      'contactRequestSent': '{name} に連絡先リクエストを送信しました。',
      'failedSendRequest': 'リクエスト送信に失敗しました: {error}',
      'notifications': '通知',
      'markAllRead': 'すべて既読',
      'noNotificationsYet': '通知はまだありません。',
      'failedLoadNotifications': '通知の読み込みに失敗しました:\n{error}',
      'failedLoadNotificationSettings': '通知設定の読み込みに失敗しました: {error}',
      'failedSaveNotificationSettings': '通知設定の保存に失敗しました: {error}',
      'noNotificationSettingsFound': '通知設定が見つかりません。',
      'newEventsLabel': '新着イベント',
      'meetupActivity': '交流募集のアクティビティ',
      'directMessages': 'ダイレクトメッセージ',
      'fieldUpdates': 'フィールド更新',
      'newEventsSubtitle': '新しいイベント公開時に通知を受け取る',
      'meetupActivitySubtitle': '交流募集の更新通知を受け取る',
      'directMessagesSubtitle': 'メッセージ受信時に通知を受け取る',
      'fieldUpdatesSubtitle': 'フィールド変更やニュースの通知を受け取る',
      'edit': '編集',
      'saveChanges': '変更を保存',
      'failedSaveProfile': 'プロフィール保存に失敗しました: {error}',
      'avatarUpdated': 'アバターを更新しました。',
      'avatarUpdateFailed': 'アバター更新に失敗しました: {error}',
      'updating': '更新中...',
      'changeAvatar': 'アバターを変更',
      'cropAvatar': 'アバターを切り抜き',
      'noProfileAvailable': 'プロフィールがありません。',
      'profileError': 'プロフィールエラー:\n{error}',
      'signedInAccount': 'ログイン中のアカウント',
      'display': '表示',
      'lightDarkControls': 'ライト/ダーク表示を設定',
      'pushNotifications': 'プッシュ通知',
      'manageAlerts': 'イベント、掲示板、DM、フィールド通知を管理',
      'privacy': 'プライバシー',
      'privacyControls': 'プライバシー管理',
      'profileVisibilityPermissions': 'プロフィール公開範囲と操作権限',
      'blockedUsers': 'ブロックしたユーザー',
      'manageBlockedAccounts': 'ブロック中アカウントを管理',
      'account': 'アカウント',
      'viewSignedInEmail': 'ログイン中メールアカウントを表示',
      'logout': 'ログアウト',
      'logoutFailed': 'ログアウトに失敗しました: {error}',
      'logoutConfirmMessage': 'アカウントからサインアウトしますか？',
      'cancel': 'キャンセル',
      'displayThemeSubtitle': '現在はダークテーマです',
      'fontSizePlaceholder': '文字サイズ調整のプレースホルダー',
      'showAreaProfile': 'プロフィールにエリアを表示',
      'showTeamProfile': 'プロフィールにチーム名を表示',
      'allowDirectMessages': 'ダイレクトメッセージを許可',
      'newEventNotifications': '新規イベント通知',
      'meetupActivityNotifications': '交流募集アクティビティ通知',
      'directMessageNotifications': 'ダイレクトメッセージ通知',
      'fieldUpdateNotifications': 'フィールド更新通知',
      'searchFieldsHint': 'フィールド名または場所で検索',
      'fieldType': 'フィールド種別',
      'minRating': '最低評価',
      'any': '指定なし',
      'noRating': '評価なし',
      'noRatingYet': 'まだ評価がありません',
      'noDescriptionAvailable': '説明はまだありません。',
      'coordinates': '座標',
      'mapViewPlaceholder': '地図ビュー準備中',
      'failedLoadFields': 'フィールドの読み込みに失敗しました: {error}',
      'noFieldsFound': 'フィールドが見つかりません。',
      'fieldMap': 'フィールドマップ',
      'board': '掲示板',
      'fieldOps': 'フィールドオプス',
    },
  };

  String get _languageCode => locale.languageCode;

  String _text(String key) => _localizedValues[_languageCode]?[key] ?? key;

  String t(String key, {Map<String, String> args = const {}}) {
    var value = _text(key);
    for (final entry in args.entries) {
      value = value.replaceAll('{${entry.key}}', entry.value);
    }
    return value;
  }

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
