// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/theme.dart';
import '../../core/models/keystore_config.dart' as model;
import '../../core/services/injection_service.dart';
import 'injection_method_card.dart';
import 'keystore_config.dart';
import 'verification_progress.dart';

/// Providers for injection UI state.
final selectedMethodProvider = StateProvider<String>((ref) => 'smali');
final apkPathProvider = StateProvider<String>((ref) => '');
final apkFileNameProvider = StateProvider<String>((ref) => '');
final apkFileSizeProvider = StateProvider<int>((ref) => 0);
final isInjectingProvider = StateProvider<bool>((ref) => false);
final keystorePathProvider = StateProvider<String>((ref) => '');
final rememberKeystoreProvider = StateProvider<bool>((ref) => false);
final stepStatesProvider = StateProvider<Map<InjectionStep, StepEvent>>(
  (ref) => {},
);

/// Full-screen desktop injection workflow.
///
/// Per D-01: Drag-drop APK zone, injection method selector,
/// keystore config, inject button, and multi-step verification progress.
class InjectionScreen extends ConsumerStatefulWidget {
  const InjectionScreen({super.key});

  @override
  ConsumerState<InjectionScreen> createState() => _InjectionScreenState();
}

class _InjectionScreenState extends ConsumerState<InjectionScreen> {
  final _keystorePasswordController = TextEditingController();
  final _keyAliasController = TextEditingController();
  final _keyPasswordController = TextEditingController();
  bool _configExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadSavedKeystorePath();
  }

  Future<void> _loadSavedKeystorePath() async {
    final path = await InjectionService.loadKeystorePath();
    if (path.isNotEmpty && mounted) {
      ref.read(keystorePathProvider.notifier).state = path;
      ref.read(rememberKeystoreProvider.notifier).state = true;
    }
  }

  @override
  void dispose() {
    _keystorePasswordController.dispose();
    _keyAliasController.dispose();
    _keyPasswordController.dispose();
    super.dispose();
  }

  Future<void> _pickApkFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['apk', 'aab'],
    );
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.path != null) {
        ref.read(apkPathProvider.notifier).state = file.path!;
        ref.read(apkFileNameProvider.notifier).state = file.name;
        ref.read(apkFileSizeProvider.notifier).state = file.size;
      }
    }
  }

  Future<void> _pickKeystore() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jks', 'keystore'],
    );
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        ref.read(keystorePathProvider.notifier).state = path;
      }
    }
  }

  Future<void> _startInjection() async {
    final apkPath = ref.read(apkPathProvider);
    final method = ref.read(selectedMethodProvider);
    final keystorePath = ref.read(keystorePathProvider);
    final remember = ref.read(rememberKeystoreProvider);

    if (apkPath.isEmpty || method.isEmpty) return;

    if (remember && keystorePath.isNotEmpty) {
      await InjectionService.saveKeystorePath(keystorePath);
    }

    final keystore = model.KeystoreConfig(
      keystorePath: keystorePath,
      keystorePassword: _keystorePasswordController.text,
      keyAlias: _keyAliasController.text,
      keyPassword: _keyPasswordController.text,
    );

    final service = InjectionService(
      pythonPath: 'python3',
      injectorScriptPath: 'performancebench-injector/injector_cli.py',
    );

    ref.read(isInjectingProvider.notifier).state = true;
    ref.read(stepStatesProvider.notifier).state = {};

    final stream = service.inject(
      apkPath: apkPath,
      method: method,
      keystore: keystore,
      outputPath: '${apkPath}_injected.apk',
      gadgetSoPath: method == 'frida' ? 'frida-gadget-arm64.so' : '',
    );

    await for (final event in stream) {
      if (!mounted) break;
      final current = Map<InjectionStep, StepEvent>.from(
        ref.read(stepStatesProvider),
      );
      current[event.step] = event;
      ref.read(stepStatesProvider.notifier).state = current;

      if (event.step == InjectionStep.done ||
          event.step == InjectionStep.error) {
        ref.read(isInjectingProvider.notifier).state = false;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final selectedMethod = ref.watch(selectedMethodProvider);
    final apkPath = ref.watch(apkPathProvider);
    final apkFileName = ref.watch(apkFileNameProvider);
    final apkFileSize = ref.watch(apkFileSizeProvider);
    final isInjecting = ref.watch(isInjectingProvider);
    final keystorePath = ref.watch(keystorePathProvider);
    final rememberKeystore = ref.watch(rememberKeystoreProvider);
    final stepStates = ref.watch(stepStatesProvider);

    final canInject = apkPath.isNotEmpty &&
        selectedMethod.isNotEmpty &&
        (selectedMethod != 'smali' || keystorePath.isNotEmpty) &&
        !isInjecting;

    return Scaffold(
      backgroundColor: colors.bgBase,
      appBar: AppBar(
        backgroundColor: colors.bgSidebar,
        title: const Text('APK Injection'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildDropZone(colors, apkFileName, apkFileSize),
            const SizedBox(height: 20),
            Text(
              'Injection Method',
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: InjectionMethodCard(
                    title: 'apktool + Smali',
                    subtitle: 'Permanent injection, requires re-signing',
                    icon: Icons.code,
                    isSelected: selectedMethod == 'smali',
                    onTap: () => ref
                        .read(selectedMethodProvider.notifier)
                        .state = 'smali',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InjectionMethodCard(
                    title: 'Frida gadget',
                    subtitle:
                        'No re-sign. Requires frida-server on device',
                    icon: Icons.device_hub,
                    isSelected: selectedMethod == 'frida',
                    onTap: () => ref
                        .read(selectedMethodProvider.notifier)
                        .state = 'frida',
                    isDisabled: false,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (selectedMethod == 'frida') ...[
              // Frida-specific info: no keystore needed
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colors.accentSuccess.withValues(alpha: 0.08),
                  border: Border.all(
                    color: colors.accentSuccess.withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline,
                        color: colors.accentSuccess, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Frida gadget injection does not require APK re-signing. '
                        'Ensure frida-server is running on the target device '
                        'before installing the injected APK.',
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (selectedMethod == 'smali') ...[
              InkWell(
                onTap: () =>
                    setState(() => _configExpanded = !_configExpanded),
                child: Row(
                  children: [
                    Icon(
                      _configExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: colors.textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Keystore Configuration',
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (_configExpanded) ...[
                const SizedBox(height: 8),
                KeystoreConfigForm(
                  keystorePath: keystorePath,
                  keystorePasswordController:
                      _keystorePasswordController,
                  keyAliasController: _keyAliasController,
                  keyPasswordController: _keyPasswordController,
                  rememberKeystore: rememberKeystore,
                  onKeystorePathChanged: (path) {
                    if (path.isEmpty) {
                      _pickKeystore();
                    }
                  },
                  onRememberChanged: (value) => ref
                      .read(rememberKeystoreProvider.notifier)
                      .state = value,
                ),
              ],
            ],
            const SizedBox(height: 20),
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
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Text('Injecting...'),
                        ],
                      )
                    : const Text(
                        'Inject',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
              ),
            ),
            const SizedBox(height: 20),
            VerificationProgress(
              stepStates: stepStates,
              isRunning: isInjecting,
              stepLabels: selectedMethod == 'frida'
                  ? const [
                      'Inject frida-gadget.so',
                      'Verify APK installs',
                    ]
                  : const [
                      'Decompile APK',
                      'Patch Smali + Manifest',
                      'Rebuild + Re-sign',
                      'Verify',
                    ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropZone(
      AppColors colors, String fileName, int fileSize) {
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => true,
      onAcceptWithDetails: (details) async {
        final path = details.data;
        if (path.endsWith('.apk') || path.endsWith('.aab')) {
          final file = File(path);
          if (await file.exists()) {
            ref.read(apkPathProvider.notifier).state = path;
            final name = path.split(Platform.pathSeparator).last;
            ref.read(apkFileNameProvider.notifier).state = name;
            ref.read(apkFileSizeProvider.notifier).state =
                await file.length();
          }
        }
      },
      builder: (context, candidateData, rejectedData) {
        final isHovering = candidateData.isNotEmpty;
        return GestureDetector(
          onTap: _pickApkFile,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 140,
            decoration: BoxDecoration(
              border: Border.all(
                color: isHovering
                    ? colors.accentBlue
                    : colors.borderSubtle,
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
        Icon(Icons.cloud_upload_outlined,
            color: colors.textSecondary, size: 36),
        const SizedBox(height: 8),
        Text(
          'Drop APK/AAB here or click to browse',
          style: TextStyle(
            color: colors.textSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Supports .apk and .aab files',
          style: TextStyle(
            color: colors.textSecondary.withValues(alpha: 0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildFileInfo(
      AppColors colors, String fileName, int fileSize) {
    final sizeMb = fileSize > 0
        ? (fileSize / (1024 * 1024)).toStringAsFixed(1)
        : '0.0';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.android, color: colors.accentSuccess, size: 32),
        const SizedBox(width: 12),
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              fileName,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$sizeMb MB',
              style: TextStyle(
                color: colors.textSecondary,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
