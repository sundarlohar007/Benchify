// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// Keystore configuration for APK re-signing.
///
/// Per D-03: Keystore credentials configured via desktop file picker.
/// Serializes to/from JSON for passing to the Python injector CLI.
class KeystoreConfig {
  final String keystorePath;
  final String keystorePassword;
  final String keyAlias;
  final String keyPassword;

  const KeystoreConfig({
    this.keystorePath = '',
    this.keystorePassword = '',
    this.keyAlias = '',
    this.keyPassword = '',
  });

  /// Serialize to JSON for passing to Python CLI as arguments.
  Map<String, dynamic> toJson() {
    return {
      'keystore_path': keystorePath,
      'keystore_password': keystorePassword,
      'key_alias': keyAlias,
      'key_password': keyPassword,
    };
  }

  /// Deserialize from JSON (e.g., from shared_preferences).
  factory KeystoreConfig.fromJson(Map<String, dynamic> json) {
    return KeystoreConfig(
      keystorePath: json['keystore_path'] as String? ?? '',
      keystorePassword: json['keystore_password'] as String? ?? '',
      keyAlias: json['key_alias'] as String? ?? '',
      keyPassword: json['key_password'] as String? ?? '',
    );
  }

  /// Whether all required keystore fields are filled.
  bool get isComplete =>
      keystorePath.isNotEmpty &&
      keyAlias.isNotEmpty;
}
