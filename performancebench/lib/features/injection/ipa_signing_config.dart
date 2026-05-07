// SPDX-License-Identifier: MIT
// Copyright (c) 2024 PerformanceBench Contributors

import 'package:flutter/material.dart';

import '../../core/models/ipa_signing_config.dart';
import '../../shared/theme.dart';

/// Signing method selector widget for iOS IPA injection.
///
/// Auto-detects available methods on build, shows radio buttons
/// with appropriate credential fields per method.
///
/// Per 05-02-PLAN Task 1 (D-07):
///   - Free Apple ID: 7-day expiry warning, Apple ID + app-specific password
///   - Paid Developer: Apple ID + Team ID + provisioning profile file picker
///   - User Certificate: certificate identity dropdown from security find-identity
class IpaSigningConfigForm extends StatefulWidget {
  final List<SigningMethod> availableMethods;
  final SigningMethod selectedMethod;
  final ValueChanged<SigningMethod> onMethodChanged;
  final TextEditingController appleIdController;
  final TextEditingController appPasswordController;
  final TextEditingController teamIdController;
  final TextEditingController certIdentityController;
  final String? provisioningProfilePath;
  final ValueChanged<String>? onProvisioningProfileChanged;
  final bool rememberCredentials;
  final ValueChanged<bool>? onRememberChanged;

  const IpaSigningConfigForm({
    super.key,
    required this.availableMethods,
    required this.selectedMethod,
    required this.onMethodChanged,
    required this.appleIdController,
    required this.appPasswordController,
    required this.teamIdController,
    required this.certIdentityController,
    this.provisioningProfilePath,
    this.onProvisioningProfileChanged,
    this.rememberCredentials = true,
    this.onRememberChanged,
  });

  @override
  State<IpaSigningConfigForm> createState() => _IpaSigningConfigFormState();
}

class _IpaSigningConfigFormState extends State<IpaSigningConfigForm> {
  bool _passwordVisible = false;
  bool _configExpanded = true;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => setState(() => _configExpanded = !_configExpanded),
          child: Row(
            children: [
              Icon(
                _configExpanded ? Icons.expand_less : Icons.expand_more,
                color: colors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Signing Configuration',
                style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: TextTokens.sm,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (_configExpanded) ...[
          const SizedBox(height: 8),
          ...widget.availableMethods.map((method) => _buildMethodRadio(colors, method)),
          const SizedBox(height: 12),
          _buildCredentialFields(colors),
          const SizedBox(height: 8),
          if (widget.selectedMethod == SigningMethod.freeAppleId)
            _buildSevenDayWarning(colors),
          _buildRememberToggle(colors),
        ],
      ],
    );
  }

  Widget _buildMethodRadio(AppColors colors, SigningMethod method) {
    final isAvailable = widget.availableMethods.contains(method);
    final isSelected = widget.selectedMethod == method;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: isAvailable ? () => widget.onMethodChanged(method) : null,
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 18,
              color: isAvailable ? colors.accentBlue : colors.textDisabled,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.displayName,
                    style: TextStyle(
                      color: isAvailable ? colors.textPrimary : colors.textDisabled,
                      fontSize: TextTokens.sm,
                    ),
                  ),
                  Text(
                    method.description,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: TextTokens.xs,
                    ),
                  ),
                ],
              ),
            ),
            if (!isAvailable)
              Text(
                'Not available',
                style: TextStyle(
                  color: colors.accentWarning,
                  fontSize: TextTokens.xs,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCredentialFields(AppColors colors) {
    final method = widget.selectedMethod;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (method == SigningMethod.freeAppleId ||
            method == SigningMethod.paidDeveloper) ...[
          // Apple ID field
          _buildTextField(
            colors: colors,
            label: 'Apple ID',
            hint: 'user@icloud.com',
            controller: widget.appleIdController,
          ),
          const SizedBox(height: 8),
          // App-specific password
          Row(
            children: [
              Expanded(
                child: _buildTextField(
                  colors: colors,
                  label: 'App-Specific Password',
                  hint: 'xxxx-xxxx-xxxx-xxxx',
                  controller: widget.appPasswordController,
                  obscure: !_passwordVisible,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  _passwordVisible ? Icons.visibility_off : Icons.visibility,
                  size: 18,
                  color: colors.textSecondary,
                ),
                onPressed: () =>
                    setState(() => _passwordVisible = !_passwordVisible),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Create an app-specific password at appleid.apple.com',
            style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.xs),
          ),
        ],
        if (method == SigningMethod.paidDeveloper) ...[
          const SizedBox(height: 8),
          _buildTextField(
            colors: colors,
            label: 'Team ID',
            hint: 'ABC123XYZ',
            controller: widget.teamIdController,
          ),
          const SizedBox(height: 8),
          _buildProfilePicker(colors),
        ],
        if (method == SigningMethod.userCertificate) ...[
          _buildTextField(
            colors: colors,
            label: 'Certificate Identity',
            hint: 'ABC123DEF456...',
            controller: widget.certIdentityController,
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required AppColors colors,
    required String label,
    required String hint,
    required TextEditingController controller,
    bool obscure = false,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(
        color: colors.textPrimary,
        fontSize: TextTokens.sm,
        fontFamily: monoFontFamily(),
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
      ),
    );
  }

  Widget _buildProfilePicker(AppColors colors) {
    return Row(
      children: [
        Expanded(
          child: Text(
            widget.provisioningProfilePath ?? 'No provisioning profile selected',
            style: TextStyle(
              color: widget.provisioningProfilePath != null
                  ? colors.textPrimary
                  : colors.textDisabled,
              fontSize: TextTokens.sm,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        TextButton(
          onPressed: () => widget.onProvisioningProfileChanged?.call(''),
          child: Text(
            'Browse...',
            style: TextStyle(color: colors.accentBlue, fontSize: TextTokens.sm),
          ),
        ),
      ],
    );
  }

  Widget _buildSevenDayWarning(AppColors colors) {
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: colors.accentWarning.withValues(alpha: 0.08),
        border: Border.all(color: colors.accentWarning.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: colors.accentWarning, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Signed apps expire after 7 days. You must re-sign and re-install weekly. '
              'Not suitable for production distribution.',
              style: TextStyle(color: colors.accentWarning, fontSize: TextTokens.xs),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRememberToggle(AppColors colors) {
    return Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: Checkbox(
            value: widget.rememberCredentials,
            onChanged: (v) => widget.onRememberChanged?.call(v ?? false),
            activeColor: colors.accentBlue,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Remember credentials in Keychain',
          style: TextStyle(color: colors.textSecondary, fontSize: TextTokens.xs),
        ),
      ],
    );
  }
}
