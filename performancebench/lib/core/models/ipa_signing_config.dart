// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

/// Signing method options for iOS IPA code signing.
///
/// Per 05-02-PLAN Task 1 (D-06):
///   - freeAppleId: Free Apple ID via altool (7-day expiry, sideload only)
///   - paidDeveloper: Paid Apple Developer account with provisioning profile
///   - userCertificate: User-provided signing certificate from Keychain
enum SigningMethod {
  freeAppleId,
  paidDeveloper,
  userCertificate;

  String get displayName {
    switch (this) {
      case SigningMethod.freeAppleId:
        return 'Free Apple ID';
      case SigningMethod.paidDeveloper:
        return 'Paid Developer Account';
      case SigningMethod.userCertificate:
        return 'User Certificate';
    }
  }

  String get description {
    switch (this) {
      case SigningMethod.freeAppleId:
        return 'Sign with Apple ID (7-day expiry). Sideload only.';
      case SigningMethod.paidDeveloper:
        return 'Sign with Apple Developer account and provisioning profile.';
      case SigningMethod.userCertificate:
        return 'Sign with a manually installed code signing certificate.';
    }
  }

  /// Parse from Python CLI value.
  factory SigningMethod.fromString(String value) {
    switch (value) {
      case 'free_apple_id':
        return SigningMethod.freeAppleId;
      case 'paid_developer':
        return SigningMethod.paidDeveloper;
      case 'user_certificate':
        return SigningMethod.userCertificate;
      default:
        return SigningMethod.freeAppleId;
    }
  }

  /// Convert to Python CLI value.
  String toPythonValue() {
    switch (this) {
      case SigningMethod.freeAppleId:
        return 'free_apple_id';
      case SigningMethod.paidDeveloper:
        return 'paid_developer';
      case SigningMethod.userCertificate:
        return 'user_certificate';
    }
  }
}

/// Configuration for iOS IPA code signing.
///
/// Holds all fields needed for the three signing methods.
/// Apple ID credentials are stored in macOS Keychain (never in files).
class IpaSigningConfig {
  final SigningMethod method;
  final String? appleId;
  final String? teamId;
  final String? provisioningProfilePath;
  final String? certIdentity;
  final bool storeInKeychain;

  const IpaSigningConfig({
    required this.method,
    this.appleId,
    this.teamId,
    this.provisioningProfilePath,
    this.certIdentity,
    this.storeInKeychain = true,
  });

  /// Whether credential fields are complete for the selected method.
  bool get isValid {
    switch (method) {
      case SigningMethod.freeAppleId:
        return appleId != null && appleId!.isNotEmpty;
      case SigningMethod.paidDeveloper:
        return appleId != null && appleId!.isNotEmpty &&
            teamId != null && teamId!.isNotEmpty &&
            provisioningProfilePath != null && provisioningProfilePath!.isNotEmpty;
      case SigningMethod.userCertificate:
        return certIdentity != null && certIdentity!.isNotEmpty;
    }
  }
}

/// Metadata about an IPA file, extracted from Info.plist.
class IpaMetadata {
  final String? appName;
  final String? bundleId;
  final String? version;
  final String? minimumOs;
  final bool encrypted;
  final String? error;

  const IpaMetadata({
    this.appName,
    this.bundleId,
    this.version,
    this.minimumOs,
    this.encrypted = false,
    this.error,
  });

  factory IpaMetadata.fromJson(Map<String, dynamic> json) {
    return IpaMetadata(
      appName: json['app_name'] as String?,
      bundleId: json['bundle_id'] as String?,
      version: json['version'] as String?,
      minimumOs: json['minimum_os'] as String?,
      encrypted: json['encrypted'] as bool? ?? false,
      error: json['error'] as String?,
    );
  }

  bool get isReady => error == null && appName != null;
  bool get cannotInject => encrypted;
}

/// Result of an IPA injection operation.
class IpaInjectionResult {
  final bool success;
  final String outputPath;
  final String signingMethodUsed;
  final List<String> warnings;
  final String? error;

  const IpaInjectionResult({
    required this.success,
    required this.outputPath,
    required this.signingMethodUsed,
    this.warnings = const [],
    this.error,
  });
}
