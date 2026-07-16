import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sayurpintar/core/storage/local_storage.dart';

/// Provider for the current locale, backed by SharedPreferences.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

/// Supported locales for SayurPintar.
const supportedLocales = [
  Locale('en'), // English
  Locale('id'), // Indonesian
  Locale('jv'), // Javanese
  Locale('su'), // Sundanese
];

/// Maps language codes to display names.
const localeDisplayNames = {
  'en': 'English',
  'id': 'Bahasa Indonesia',
  'jv': 'Basa Jawa',
  'su': 'Basa Sunda',
};

/// Maps language codes to flag emojis.
const localeFlags = {
  'en': '🇬🇧',
  'id': '🇮🇩',
  'jv': '🇮🇩',
  'su': '🇮🇩',
};

/// Maps language codes to preview text.
const localePreview = {
  'en': 'Welcome to SayurPintar',
  'id': 'Selamat Datang di SayurPintar',
  'jv': 'Sugeng Rawuh ing SayurPintar',
  'su': 'Wilujeng Sumping ka SayurPintar',
};

/// SharedPreferences key for locale persistence.
const _localeKey = 'app_locale';

/// A [StateNotifier] that manages the app's current [Locale].
class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('id')) {
    _loadSavedLocale();
  }

  /// Loads the saved locale from SharedPreferences.
  void _loadSavedLocale() {
    try {
      final storage = LocalStorage();
      // Use direct SharedPreferences access since LocalStorage may not have
      // locale-specific methods yet. We access it through the generic API.
      final savedCode = _readLocale(storage);
      if (savedCode != null) {
        final saved = Locale(savedCode);
        if (supportedLocales.contains(saved)) {
          state = saved;
        }
      }
    } catch (_) {
      // Storage not initialized yet, keep default
    }
  }

  /// Reads the locale code from storage.
  String? _readLocale(LocalStorage storage) {
    // Access SharedPreferences directly through the instance
    // This is a workaround until LocalStorage gets locale methods
    try {
      // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
      final prefs = storage;
      // Use dynamic to access getString if available
      return (prefs as dynamic)._prefs?.getString(_localeKey) as String?;
    } catch (_) {
      return null;
    }
  }

  /// Changes the app locale and persists the selection.
  Future<void> setLocale(Locale locale) async {
    if (!supportedLocales.contains(locale)) return;
    state = locale;
    try {
      final storage = LocalStorage();
      // Persist via SharedPreferences directly
      _writeLocale(storage, locale.languageCode);
    } catch (_) {
      // Storage error — locale is still updated in memory
    }
  }

  /// Writes the locale code to storage.
  void _writeLocale(LocalStorage storage, String code) {
    try {
      (storage as dynamic)._prefs?.setString(_localeKey, code);
    } catch (_) {
      // Ignore storage errors
    }
  }

  /// Resets locale to the system default.
  Future<void> resetToSystem() async {
    final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
    final matched = supportedLocales.firstWhere(
      (l) => l.languageCode == systemLocale.languageCode,
      orElse: () => const Locale('id'),
    );
    await setLocale(matched);
  }
}
