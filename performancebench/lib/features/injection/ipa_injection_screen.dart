// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/ipa_signing_config.dart';
import '../../core/services/ipa_injection_service.dart';
import '../../shared/theme.dart';
import 'ipa_signing_config.dart';
import 'ipa_verification_progress.dart';

/// Providers for iOS IPA injection UI state.
final ipaPathProvider = StateProvider<String>((ref) => '');
final ipaFileNameProvider = StateProvider<String>((ref) => '');
final ipaFileSizeProvider = StateProvider<int>((ref) => 0);
final ipaMetadataProvider = StateProvider<IpaMetadata?>((ref) => null);
final ipaIsInjectingProvider = StateProvider<bool>((ref) => false);
final ipaSelectedMethodProvider = StateProvider<SigningMethod>(
  (ref) => SigningMethod.freeAppleId,
);
final ipaAvailableMethodsProvider = StateProvider<List<SigningMethod>>(
  (ref) => [],
);
final ipaStepStatesProvider = StateProvider<Map<IpaInjectionStep, IpaStepEvent>>(
  (ref) => {},
);

/// iOS IPA injection tab for the desktop injection screen.
///
/// Per 05-02-PLAN Task 1 (D-07):
///   Drag-drop IPA zone, metadata card (app name, bundle ID, version,
///   encryption status), signing method selector with auto-detect,
///   credential fields, verification progress stepper.
///
/// Reuses Phase 4 injection screen TabBar pattern: adds "iOS" tab
/// alongside existing "Android" tab in injection_screen.dart.
class IpaInjectionScreen extends ConsumerStatefulWidget {
  const IpaInjectionScreen({super.key});

  @override
  ConsumerState<IpaInjectionScreen> createState() => _IpaInjectionScreenState();
}

class _IpaInjectionScreenState extends ConsumerState<IpaInjectionScreen> {
  final _appleIdController = TextEditingController();
  final _appPasswordController = TextEditingController();
  final _teamIdController = TextEditingController();
  final _certIdentityController = TextEditingController();
  String? _provisioningProfilePath;
  bool _rememberCredentials = true;

  @override
  void dispose() {
    _appleIdController.dispose();
    _appPasswordController.dispose();
    _teamIdController.dispose();
    _certIdentityController.dispose();
    super.dispose();
  }

  Future<void> _pickIpaFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['ipa'],
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.path != null) {
        ref.read(ipaPathProvider.notifier).state = file.path!;
        ref.read(ipaFileNameProvider.notifier).state = file.name;
        ref.read(ipaFileSizeProvider.notifier).state = file.size;

        // Read metadata and auto-detect signing methods
        await _loadIpaMetadata(file.path!);
        await _detectSigningMethods();
      }
    }
  }

  Future<void> _loadIpaMetadata(String ipaPath) async {
    final service = IpaInjectionService(
      pythonPath: 'python3',
      injectorScriptPath: 'performancebench-injector/injector_cli.py',
    );
    final metadata = await service.getIpaMetadata(ipaPath);
    if (mounted) {
      ref.read(ipaMetadataProvider.notifier).state = metadata;
    }
  }

  Future<void> _detectSigningMethods() async {
    final service = IpaInjectionService(
      pythonPath: 'python3',
      injectorScriptPath: 'performancebench-injector/injector_cli.py',
    );
    final methods = await service.detectSigningMethods();
    if (mounted) {
      ref.read(ipaAvailableMethodsProvider.notifier).state = methods;
      // Default to first available method
      if (methods.isNotEmpty) {
        final current = ref.read(ipaSelectedMethodProvider);
        if (!methods.contains(current)) {
          ref.read(ipaSelectedMethodProvider.notifier).state = methods.first;
        }
      }
    }
  }

  Future<void> _startInjection() async {
    final ipaPath = ref.read(ipaPathProvider);
    final method = ref.read(ipaSelectedMethodProvider);

    if (ipaPath.isEmpty) return;

    final config = IpaSigningConfig(
      method: method,
      appleId: _appleIdController.text.isNotEmpty
          ? _appleIdController.text
          : null,
      teamId: _teamIdController.text.isNotEmpty
          ? _teamIdController.text
          : null,
      provisioningProfilePath: _provisioningProfilePath,
      certIdentity: _certIdentityController.text.isNotEmpty
          ? _certIdentityController.text
          : null,
      storeInKeychain: _rememberCredentials,
    );

    if (!config.isValid) return;

    final service = IpaInjectionService(
      pythonPath: 'python3',
      injectorScriptPath: 'performancebench-injector/injector_cli.py',
    );

    ref.read(ipaIsInjectingProvider.notifier).state = true;
    ref.read(ipaStepStatesProvider.notifier).state = {};

    final outputPath = '${ipaPath}_injected.ipa';
    final stream = service.injectIpa(
      ipaPath: ipaPath,
      outputPath: outputPath,
      config: config,
      appSpecificPassword: _appPasswordController.text.isNotEmpty
          ? _appPasswordController.text
          : null,
    );

    await for (final event in stream) {
      if (!mounted) break;
      final current = Map<IpaInjectionStep, IpaStepEvent>.from(
        ref.read(ipaStepStatesProvider),
      );
      current[event.step] = event;
      ref.read(ipaStepStatesProvider.notifier).state = current;

      if (event.step == IpaInjectionStep.done ||
          event.step == IpaInjectionStep.error) {
        ref.read(ipaIsInjectingProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final ipaPath = ref.watch(ipaPathProvider);
    final ipaFileName = ref.watch(ipaFileNameProvider);
    final ipaFileSize = ref.watch(ipaFileSizeProvider);
    final metadata = ref.watch(ipaMetadataProvider);
    final isInjecting = ref.watch(ipaIsInjectingProvider);
    final selectedMethod = ref.watch(ipaSelectedMethodProvider);
    final availableMethods = ref.watch(ipaAvailableMethodsProvider);
    final stepStates = ref.watch(ipaStepStatesProvider);

    final isSupported = IpaInjectionService.isSupported;
    final canInject = ipaPath.isNotEmpty &&
        !isInjecting &&
        metadata != null &&
        !metadata.cannotInject;

    return Scaffold(
      backgroundColor: colors.bgBase,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Platform notice
            if (!isSupported)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colors.accentWarning.withValues(alpha: 0.08),
                  border: Border.all(
                    color: colors.accentWarning.withValues(alpha: 0.25),
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: colors.accentWarning, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'iOS IPA injection requires macOS. '
                        'Xcode command line tools and Python 3 must be installed.',
                        style: TextStyle(
                          color: colors.accentWarning,
                          fontSize: TextTokens.xs,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // Drop zone
            _buildDropZone(colors, ipaFileName, ipaFileSize),
            const SizedBox(height: 16),

            // IPA metadata card
            if (metadata != null && metadata.isReady) ...[
              _buildMetadataCard(colors, metadata),
              const SizedBox(height: 16),
            ],

            // Encryption warning
            if (metadata != null && metadata.cannotInject)
              _buildEncryptedWarning(colors),

            if (metadata != null && !metadata.cannotInject && isSupported) ...[
              // Signing method selector
              const SizedBox(height: 8),
              Text(
                'Signing Method',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: TextTokens.md,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (availableMethods.isEmpty && ipaPath.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: colors.accentBlue,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Detecting available signing methods...',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: TextTokens.sm,
                        ),
                      ),
                    ],
                  ),
                ),
              if (availableMethods.isNotEmpty)
                IpaSigningConfigForm(
                  availableMethods: availableMethods,
                  selectedMethod: selectedMethod,
                  onMethodChanged: (method) =>
                      ref.read(ipaSelectedMethodProvider.notifier).state = method,
                  appleIdController: _appleIdController,
                  appPasswordController: _appPasswordController,
                  teamIdController: _teamIdController,
                  certIdentityController: _certIdentityController,
                  provisioningProfilePath: _provisioningProfilePath,
                  onProvisioningProfileChanged: (path) =>
                      setState(() => _provisioningProfilePath = path),
                  rememberCredentials: _rememberCredentials,
                  onRememberChanged: (v) =>
                      setState(() => _rememberCredentials = v),
                ),

              const SizedBox(height: 16),

              // Inject button
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: canInject ? _startInjection : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accentBlue,
                    disabledBackgroundColor:
                        colors.accentBlue.withValues(alpha: 0.3),
                    foregroundColor: colors.textPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: isInjecting
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2, color: colors.textPrimary,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text('Injecting...'),
                          ],
                        )
                      : const Text(
                          'Inject',
                          style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // Verification progress
              IpaVerificationProgress(
                stepStates: stepStates,
                isRunning: isInjecting,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDropZone(AppColors colors, String fileName, int fileSize) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) async {
        final path = details.data;
        if (path.endsWith('.ipa')) {
          final file = File(path);
          if (await file.exists()) {
            ref.read(ipaPathProvider.notifier).state = path;
            final name = path.split(Platform.pathSeparator).last;
            ref.read(ipaFileNameProvider.notifier).state = name;
            ref.read(ipaFileSizeProvider.notifier).state = await file.length();
            await _loadIpaMetadata(path);
            await _detectSigningMethods();
          }
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return GestureDetector(
          onTap: _pickIpaFile,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(
                color: isHovering ? colors.accentBlue : colors.borderSubtle,
                width: isHovering ? 2 : 1,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
              borderRadius: BorderRadius.circular(8),
              color: isHovering
                  ? colors.accentBlue.withValues(alpha: 0.05)
                  : colors.bgElevated,
            ),
            child: fileName.isEmpty
                ? _buildEmptyDropZone(colors)
                : _buildFileInfo(colors, fileName, fileSize),
          ),
        );
      },
    );
  }

  Widget _buildEmptyDropZone(AppColors colors) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.phone_iphone, color: colors.textSecondary, size: 36),
        const SizedBox(height: 8),
        Text(
          'Drop IPA here or click to browse',
          style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.md),
        ),
        const SizedBox(height: 4),
        Text(
          'Supports unencrypted .ipa files (studio builds only)',
          style: TextStyle(
            color: colors.textSecondary.withValues(alpha: 0.6),
            fontSize: TextTokens.xs,
          ),
        ),
      ],
    );
  }

  Widget _buildFileInfo(AppColors colors, String fileName, int fileSize) {
    final sizeMb = fileSize > 0
        ? (fileSize / (1024 * 1024)).toStringAsFixed(1)
        : '0.0';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.phone_iphone, color: colors.accentSuccess, size: 32),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fileName,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: TextTokens.sm,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$sizeMb MB',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: TextTokens.xs,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetadataCard(AppColors colors, IpaMetadata metadata) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.bgElevated,
        border: Border.all(color: colors.borderSubtle),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                metadata.appName ?? 'Unknown',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: TextTokens.md,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              _buildEncryptionBadge(colors, metadata),
            ],
          ),
          const SizedBox(height: 6),
          _buildMetadataRow(colors, 'Bundle ID', metadata.bundleId),
          _buildMetadataRow(colors, 'Version', metadata.version),
          _buildMetadataRow(colors, 'Minimum OS', metadata.minimumOs),
        ],
      ),
    );
  }

  Widget _buildMetadataRow(AppColors colors, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.xs),
          ),
          Text(
            value ?? '—',
            style: TextStyle(color: colors.textPrimary, fontSize: TextTokens.xs),
          ),
        ],
      ),
    );
  }

  Widget _buildEncryptionBadge(AppColors colors, IpaMetadata metadata) {
    final isEncrypted = metadata.encrypted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isEncrypted
            ? colors.accentDanger.withValues(alpha: 0.1)
            : colors.accentSuccess.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isEncrypted
              ? colors.accentDanger.withValues(alpha: 0.3)
              : colors.accentSuccess.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        isEncrypted ? 'Encrypted' : 'Unencrypted',
        style: TextStyle(
          color: isEncrypted ? colors.accentDanger : colors.accentSuccess,
          fontSize: TextTokens.xs,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEncryptedWarning(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: colors.accentDanger.withValues(alpha: 0.08),
        border: Border.all(color: colors.accentDanger.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock, color: colors.accentDanger, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This IPA is encrypted with FairPlay DRM.',
                  style: TextStyle(
                    color: colors.accentDanger,
                    fontSize: TextTokens.sm,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Only unencrypted studio builds can be injected. '
                  'App Store IPAs are encrypted and cannot be modified. '
                  'Request an unencrypted build from your development team.',
                  style: TextStyle(
                    color: colors.accentDanger,
                    fontSize: TextTokens.xs,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
