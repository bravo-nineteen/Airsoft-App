import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AnnualMembershipService {
  AnnualMembershipService._();

  static final AnnualMembershipService instance = AnnualMembershipService._();

  static const String _membershipExpiresAtKey = 'annual_membership_expires_at';
  static const String _membershipPurchaseTokenKey =
      'annual_membership_purchase_token';
  static const String _membershipStatusKey = 'annual_membership_is_active';

  static String get productId {
    final String subscriptionId = const String.fromEnvironment(
      'IAP_ANNUAL_MEMBERSHIP_SUBSCRIPTION_ID',
    ).trim();
    if (subscriptionId.isNotEmpty) {
      return subscriptionId;
    }

    return const String.fromEnvironment('IAP_ANNUAL_MEMBERSHIP_PRODUCT_ID')
        .trim();
  }

  final ValueNotifier<bool> isAdFreeNotifier = ValueNotifier<bool>(false);

  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  bool _initialized = false;
  bool _refreshing = false;
  Completer<PurchaseDetails?>? _purchaseCompleter;

  bool get isConfigured => productId.isNotEmpty;

  Future<void> ensureInitialized() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    _purchaseSubscription = InAppPurchase.instance.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object error) {
        debugPrint('Annual membership purchase stream error: $error');
      },
    );

    await refreshEntitlement();
  }

  Future<void> dispose() async {
    await _purchaseSubscription?.cancel();
  }

  Future<void> refreshEntitlement() async {
    if (_refreshing) {
      return;
    }
    _refreshing = true;

    try {
      final bool localActive = await _readLocalEntitlement();
      if (localActive) {
        isAdFreeNotifier.value = true;
        return;
      }

      final bool remoteActive = await _readRemoteEntitlement();
      isAdFreeNotifier.value = remoteActive;
      if (remoteActive) {
        return;
      }

      isAdFreeNotifier.value = false;
    } finally {
      _refreshing = false;
    }
  }

  Future<bool> isAdFree() async {
    await ensureInitialized();
    if (isAdFreeNotifier.value) {
      return true;
    }
    await refreshEntitlement();
    return isAdFreeNotifier.value;
  }

  Future<DateTime?> getCachedExpiry() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? expiresAtText = prefs.getString(_membershipExpiresAtKey);
    return DateTime.tryParse(expiresAtText ?? '')?.toUtc();
  }

  Future<String?> getCachedPurchaseToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString(_membershipPurchaseTokenKey);
    if (token == null || token.trim().isEmpty) {
      return null;
    }
    return token.trim();
  }

  Future<List<ProductDetails>> loadProducts() async {
    await ensureInitialized();
    if (!isConfigured) {
      return const <ProductDetails>[];
    }

    final ProductDetailsResponse response = await InAppPurchase.instance
        .queryProductDetails(<String>{productId});
    return response.productDetails;
  }

  Future<PurchaseDetails?> purchaseAnnualMembership() async {
    await ensureInitialized();
    final List<ProductDetails> products = await loadProducts();
    if (products.isEmpty) {
      throw Exception(
        'Google Play annual membership subscription is not configured.',
      );
    }

    final ProductDetails product = products.first;
    final Completer<PurchaseDetails?> completer =
        Completer<PurchaseDetails?>();
    _purchaseCompleter = completer;

    try {
      final PurchaseParam purchaseParam = _buildPurchaseParam(product);
      await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: purchaseParam,
      );
    } catch (error) {
      _purchaseCompleter = null;
      rethrow;
    }

    return completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        _purchaseCompleter = null;
        return null;
      },
    );
  }

  PurchaseParam _buildPurchaseParam(ProductDetails product) {
    if (defaultTargetPlatform == TargetPlatform.android &&
        product is GooglePlayProductDetails) {
      final String? offerToken = product.offerToken;
      if (offerToken != null && offerToken.isNotEmpty) {
        return GooglePlayPurchaseParam(
          productDetails: product,
          offerToken: offerToken,
        );
      }
    }

    return PurchaseParam(productDetails: product);
  }

  Future<void> restorePurchases() async {
    await ensureInitialized();
    await InAppPurchase.instance.restorePurchases();
  }

  Future<void> _handlePurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _finalizeSuccessfulPurchase(purchaseDetails);
          break;
        case PurchaseStatus.error:
          _completePurchase(purchaseDetails);
          break;
        case PurchaseStatus.canceled:
          _completePurchase(purchaseDetails);
          break;
      }

      if (purchaseDetails.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(purchaseDetails);
      }
    }
  }

  Future<void> _finalizeSuccessfulPurchase(PurchaseDetails purchase) async {
    final DateTime transactionTime = _readTransactionTimeUtc(purchase);
    final DateTime expiresAt = transactionTime.add(const Duration(days: 365));

    await _persistLocalEntitlement(
      expiresAt: expiresAt,
      purchaseToken: purchase.verificationData.serverVerificationData,
    );
    await _syncRemoteEntitlement(expiresAt: expiresAt, purchase: purchase);
    isAdFreeNotifier.value = true;

    _completePurchase(purchase);
  }

  DateTime _readTransactionTimeUtc(PurchaseDetails purchase) {
    final int? millis = int.tryParse(purchase.transactionDate ?? '');
    if (millis == null) {
      return DateTime.now().toUtc();
    }
    return DateTime.fromMillisecondsSinceEpoch(millis, isUtc: true);
  }

  void _completePurchase(PurchaseDetails purchase) {
    final completer = _purchaseCompleter;
    if (completer == null || completer.isCompleted) {
      return;
    }
    if (purchase.status == PurchaseStatus.error ||
        purchase.status == PurchaseStatus.canceled) {
      completer.complete(null);
      _purchaseCompleter = null;
      return;
    }

    completer.complete(purchase);
    _purchaseCompleter = null;
  }

  Future<bool> _readLocalEntitlement() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? expiresAtText = prefs.getString(_membershipExpiresAtKey);
    final DateTime? expiresAt = DateTime.tryParse(expiresAtText ?? '')?.toUtc();
    if (expiresAt == null) {
      return false;
    }

    if (!expiresAt.isAfter(DateTime.now().toUtc())) {
      return false;
    }

    return prefs.getBool(_membershipStatusKey) ?? true;
  }

  Future<bool> _readRemoteEntitlement() async {
    final SupabaseClient? client = _supabaseClient;
    if (client == null) {
      return false;
    }

    final User? user = client.auth.currentUser;
    if (user == null) {
      return false;
    }

    final DateTime nowUtc = DateTime.now().toUtc();
    final List<dynamic> rows = await client
        .from('ad_free_membership_requests')
        .select('status, expires_at')
        .eq('requester_user_id', user.id)
        .order('created_at', ascending: false)
        .limit(5);

    for (final dynamic row in rows) {
      if (row is! Map) {
        continue;
      }
      final Map<String, dynamic> record = Map<String, dynamic>.from(row);
      final String status = (record['status'] ?? '').toString().toLowerCase();
      if (status != 'active') {
        continue;
      }
      final DateTime? expiresAt = DateTime.tryParse(
        (record['expires_at'] ?? '').toString(),
      )?.toUtc();
      if (expiresAt != null && expiresAt.isAfter(nowUtc)) {
        await _persistLocalEntitlement(
          expiresAt: expiresAt,
          purchaseToken: null,
        );
        return true;
      }
    }

    return false;
  }

  Future<void> _persistLocalEntitlement({
    required DateTime expiresAt,
    required String? purchaseToken,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_membershipExpiresAtKey, expiresAt.toIso8601String());
    await prefs.setBool(_membershipStatusKey, true);
    if (purchaseToken != null && purchaseToken.trim().isNotEmpty) {
      await prefs.setString(
        _membershipPurchaseTokenKey,
        purchaseToken.trim(),
      );
    }
  }

  Future<void> _syncRemoteEntitlement({
    required DateTime expiresAt,
    required PurchaseDetails purchase,
  }) async {
    final SupabaseClient? client = _supabaseClient;
    if (client == null) {
      return;
    }

    final User? user = client.auth.currentUser;
    if (user == null) {
      return;
    }

    final String email = user.email?.trim().isNotEmpty == true
        ? user.email!.trim()
        : 'unknown@airsoft.app';
    final String fullName = user.userMetadata?['full_name']?.toString().trim().isNotEmpty == true
        ? user.userMetadata!['full_name'].toString().trim()
        : (user.userMetadata?['name']?.toString().trim().isNotEmpty == true
              ? user.userMetadata!['name'].toString().trim()
              : 'Google Play Member');

    await client.from('ad_free_membership_requests').insert({
      'requester_user_id': user.id,
      'full_name': fullName,
      'contact_email': email,
      'notes': 'Purchased via Google Play subscription billing.',
      'annual_fee_yen': 5000,
      'payment_platform': 'google_play',
      'status': 'active',
      'payment_request_sent_at': DateTime.now().toUtc().toIso8601String(),
      'activated_at': DateTime.now().toUtc().toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'admin_note': 'Auto-activated after Google Play subscription purchase.',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'payment_reference': purchase.verificationData.serverVerificationData,
    });
  }

  SupabaseClient? get _supabaseClient {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }
}