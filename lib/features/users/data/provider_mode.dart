import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProviderMode extends Notifier<bool> {
  @override
  bool build() => false;

  void toggleMode(bool isProvider) {
    state = isProvider;
  }
}

final providerModeProvider = NotifierProvider<ProviderMode, bool>(
  ProviderMode.new,
);
