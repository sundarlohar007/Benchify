// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';
import '../../shared/theme.dart';

/// Keystore configuration form widget.
///
/// Per D-03: Keystore via desktop file picker + password fields.
/// Provides file picker for .jks/.keystore files, obscure-text password fields,
/// and "Remember keystore" checkbox.
///
/// Threat mitigations:
/// - T-04-06: Password fields use obscureText: true.
///   Keystore path stored only if user opts in via "Remember" checkbox.
class KeystoreConfigForm extends StatefulWidget {
  final String keystorePath;
  final TextEditingController keystorePasswordController;
  final TextEditingController keyAliasController;
  final TextEditingController keyPasswordController;
  final bool rememberKeystore;
  final ValueChanged<String> onKeystorePathChanged;
  final ValueChanged<bool> onRememberChanged;

  const KeystoreConfigForm({
    super.key,
    required this.keystorePath,
    required this.keystorePasswordController,
    required this.keyAliasController,
    required this.keyPasswordController,
    required this.rememberKeystore,
    required this.onKeystorePathChanged,
    required this.onRememberChanged,
  });

  @override
  State<KeystoreConfigForm> createState() => _KeystoreConfigFormState();
}

class _KeystoreConfigFormState extends State<KeystoreConfigForm> {
  bool _showKeystorePass = false;
  bool _showKeyPass = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.bgElevated,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Keystore Configuration',
            style: TextStyle(
              color: colors.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildFilePicker(colors),
          const SizedBox(height: 12),
          _buildPasswordField(
            colors,
            controller: widget.keystorePasswordController,
            label: 'Keystore Password',
            showPassword: _showKeystorePass,
            onToggle: () =>
                setState(() => _showKeystorePass = !_showKeystorePass),
          ),
          const SizedBox(height: 10),
          _buildTextField(
            colors,
            controller: widget.keyAliasController,
            label: 'Key Alias',
            hint: 'e.g., mykey',
          ),
          const SizedBox(height: 10),
          _buildPasswordField(
            colors,
            controller: widget.keyPasswordController,
            label: 'Key Password',
            showPassword: _showKeyPass,
            onToggle: () => setState(() => _showKeyPass = !_showKeyPass),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: Checkbox(
                  value: widget.rememberKeystore,
                  onChanged: (v) => widget.onRememberChanged(v ?? false),
                  activeColor: colors.accentBlue,
                  checkColor: colors.bgBase,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Remember keystore path',
                style: TextStyle(
                  color: colors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilePicker(AppColors colors) {
    return GestureDetector(
      onTap: () {
        widget.onKeystorePathChanged(widget.keystorePath);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: colors.bgInput,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: colors.borderSubtle),
        ),
        child: Row(
          children: [
            Icon(Icons.folder_open, color: colors.textSecondary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.keystorePath.isEmpty
                    ? 'Select keystore file (.jks / .keystore)...'
                    : widget.keystorePath,
                style: TextStyle(
                  color: widget.keystorePath.isEmpty
                      ? colors.textSecondary.withValues(alpha: 0.6)
                      : colors.textPrimary,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    AppColors colors, {
    required TextEditingController controller,
    required String label,
    String hint = '',
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          style: TextStyle(color: colors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: colors.textSecondary.withValues(alpha: 0.5),
              fontSize: 12,
            ),
            filled: true,
            fillColor: colors.bgInput,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: colors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: colors.borderSubtle),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField(
    AppColors colors, {
    required TextEditingController controller,
    required String label,
    required bool showPassword,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(color: colors.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 4),
        TextFormField(
          controller: controller,
          obscureText: !showPassword,
          style: TextStyle(color: colors.textPrimary, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: colors.bgInput,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: colors.borderSubtle),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(4),
              borderSide: BorderSide(color: colors.borderSubtle),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            suffixIcon: IconButton(
              icon: Icon(
                showPassword ? Icons.visibility_off : Icons.visibility,
                color: colors.textSecondary,
                size: 18,
              ),
              onPressed: onToggle,
            ),
          ),
        ),
      ],
    );
  }
}
