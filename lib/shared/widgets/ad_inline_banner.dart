import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../../core/ads/ad_config.dart';
import '../services/annual_membership_service.dart';

class AdInlineBanner extends StatefulWidget {
  const AdInlineBanner({super.key, this.margin});

  final EdgeInsetsGeometry? margin;

  @override
  State<AdInlineBanner> createState() => _AdInlineBannerState();
}

class _AdInlineBannerState extends State<AdInlineBanner> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  final AnnualMembershipService _membershipService =
      AnnualMembershipService.instance;

  @override
  void initState() {
    super.initState();
    _membershipService.isAdFreeNotifier.addListener(_handleMembershipChanged);
    unawaited(_initializeAndLoad());
  }

  Future<void> _initializeAndLoad() async {
    await _membershipService.ensureInitialized();
    if (!mounted || _membershipService.isAdFreeNotifier.value) {
      return;
    }
    _loadAd();
  }

  void _handleMembershipChanged() {
    if (!mounted) {
      return;
    }

    if (_membershipService.isAdFreeNotifier.value) {
      setState(() {
        _isLoaded = false;
      });
      _bannerAd?.dispose();
      _bannerAd = null;
      return;
    }

    if (_bannerAd == null && !_isLoaded) {
      _loadAd();
    }
  }

  void _loadAd() {
    final String? adUnitId = AdConfig.bannerAdUnitId;
    if (adUnitId == null) {
      return;
    }

    final BannerAd bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() {
            _bannerAd = ad as BannerAd;
            _isLoaded = true;
          });
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
        },
      ),
    );

    bannerAd.load();
  }

  @override
  void dispose() {
    _membershipService.isAdFreeNotifier.removeListener(_handleMembershipChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_membershipService.isAdFreeNotifier.value) {
      return const SizedBox.shrink();
    }

    if (!_isLoaded || _bannerAd == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: widget.margin ?? const EdgeInsets.symmetric(vertical: 6),
      alignment: Alignment.center,
      child: SizedBox(
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}
