import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProviderMode extends Notifier<bool> {
  @override
  bool build() => false;

  void setMode(bool isProvider) {
    state = isProvider;
  }

  void toggleMode(bool isProvider) {
    setMode(isProvider);
  }
}

final providerModeProvider = NotifierProvider<ProviderMode, bool>(
  ProviderMode.new,
);
