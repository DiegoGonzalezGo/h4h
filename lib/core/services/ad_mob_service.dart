import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdMobService with WidgetsBindingObserver {
  AdMobService._() {
    WidgetsBinding.instance.addObserver(this);
  }

  static final AdMobService instance = AdMobService._();

  static const _androidInterstitialTestId =
      'ca-app-pub-3940256099942544/1033173712';
  static const _iosInterstitialTestId =
      'ca-app-pub-3940256099942544/4411468910';
  static const _firstAdDelay = Duration(minutes: 1);
  static const _repeatAdInterval = Duration(minutes: 8);

  static bool get isSupportedPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  InterstitialAd? _interstitialAd;
  bool _isLoading = false;
  bool _isInterstitialShowing = false;
  int _adRequestGeneration = 0;
  final List<VoidCallback> _pendingCallbacks = [];
  Timer? _firstAdTimer;
  Timer? _repeatAdTimer;
  bool _adTimersEnabled = false;
  bool _firstTimedAdDismissed = false;

  static bool shouldShowAds(Map<String, dynamic> userData) {
    final plan = userData['plan']?.toString().toLowerCase();
    final isPro = userData['isPro'] == true || plan == 'pro' || plan == 'elite';
    final isElite =
        userData['isElite'] == true ||
        userData['isPremium'] == true ||
        plan == 'elite';

    return userData['adsDisabled'] != true &&
        !isPro &&
        !isElite &&
        (plan == null ||
            plan.isEmpty ||
            plan == 'gratis' ||
            plan == 'free');
  }

  void startAdTimers() {
    if (!isSupportedPlatform) return;
    _adTimersEnabled = true;
    loadInterstitialAd();
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
      _scheduleNextAd();
    }
  }

  void cancelAdTimers() {
    _adTimersEnabled = false;
    _firstAdTimer?.cancel();
    _firstAdTimer = null;
    _repeatAdTimer?.cancel();
    _repeatAdTimer = null;
    _firstTimedAdDismissed = false;
    _adRequestGeneration++;
    _pendingCallbacks.clear();
    _interstitialAd?.dispose();
    _interstitialAd = null;
    _isLoading = false;
  }

  void loadInterstitialAd() {
    if (!isSupportedPlatform || _isLoading || _interstitialAd != null) return;

    final adUnitId = _testInterstitialAdUnitId;
    if (adUnitId == null) return;

    final requestGeneration = _adRequestGeneration;
    _isLoading = true;
    InterstitialAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          if (requestGeneration != _adRequestGeneration) {
            ad.dispose();
            return;
          }
          _isLoading = false;
          _interstitialAd = ad;
          _showNextPendingCallback();
        },
        onAdFailedToLoad: (error) {
          if (requestGeneration != _adRequestGeneration) return;
          _isLoading = false;
          debugPrint('No se pudo cargar el intersticial de prueba: $error');
          _completePendingCallbacks();
        },
      ),
    );
  }

  void showInterstitialAd(VoidCallback onAdDismissed) {
    _pendingCallbacks.add(onAdDismissed);
    if (!_isInterstitialShowing) _showNextPendingCallback();
  }

  void _showNextPendingCallback() {
    if (_isInterstitialShowing || _pendingCallbacks.isEmpty) return;

    final ad = _interstitialAd;
    if (ad == null) {
      loadInterstitialAd();
      return;
    }

    final callback = _pendingCallbacks.removeAt(0);
    _interstitialAd = null;
    _isInterstitialShowing = true;
    var callbackCompleted = false;

    void complete() {
      if (callbackCompleted) return;
      callbackCompleted = true;
      ad.dispose();
      _isInterstitialShowing = false;
      callback();
      if (_pendingCallbacks.isNotEmpty || _adTimersEnabled) {
        loadInterstitialAd();
      }
    }

    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (ad) => complete(),
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('No se pudo mostrar el intersticial de prueba: $error');
        complete();
      },
    );

    try {
      ad.show();
    } catch (error, stackTrace) {
      debugPrint('Error al mostrar el intersticial de prueba: $error');
      debugPrintStack(stackTrace: stackTrace);
      complete();
    }
  }

  void _scheduleNextAd() {
    if (!_adTimersEnabled ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    if (_firstTimedAdDismissed) {
      _repeatAdTimer?.cancel();
      _repeatAdTimer = Timer.periodic(_repeatAdInterval, (_) {
        if (_adTimersEnabled && !_isInterstitialShowing) {
          showInterstitialAd(() {});
        }
      });
    } else {
      _firstAdTimer?.cancel();
      _firstAdTimer = Timer(_firstAdDelay, () {
        if (!_adTimersEnabled) return;
        showInterstitialAd(() {
          _firstTimedAdDismissed = true;
          _scheduleNextAd();
        });
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_adTimersEnabled) return;

    if (state == AppLifecycleState.resumed) {
      _scheduleNextAd();
      if (_interstitialAd == null && !_isLoading) loadInterstitialAd();
    } else {
      _firstAdTimer?.cancel();
      _firstAdTimer = null;
      _repeatAdTimer?.cancel();
      _repeatAdTimer = null;
    }
  }

  void _completePendingCallbacks() {
    final callbacks = List<VoidCallback>.from(_pendingCallbacks);
    _pendingCallbacks.clear();
    for (final callback in callbacks) {
      callback();
    }
  }

  String? get _testInterstitialAdUnitId {
    if (!isSupportedPlatform) return null;

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => _androidInterstitialTestId,
      TargetPlatform.iOS => _iosInterstitialTestId,
      _ => null,
    };
  }
}
