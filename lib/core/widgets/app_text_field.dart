/// Reusable RTL-aware text field for Tarmeem forms.
///
/// Implements the design-spec input style: 52px height, rounded-xl corners,
/// teal focus ring, right-aligned Arabic text input.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/color_tokens.dart';

/// A styled text field matching the Tarmeem design system.
class TarmeemTextField extends StatelessWidget {
  const TarmeemTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.suffixWidget,
    this.keyboardType,
    this.validator,
    this.onChanged,
    this.inputFormatters,
    this.maxLines = 1,
    this.minLines,
    this.readOnly = false,
    this.enabled = true,
    this.autofocus = false,
    this.textDirection,
    this.onTap,
  });

  final TextEditingController? controller;
  final String label;
  final String? hint;
  final Widget? prefixIcon;
  final Widget? suffixWidget;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLines;
  final int? minLines;
  final bool readOnly;
  final bool enabled;
  final bool autofocus;
  final TextDirection? textDirection;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          label,
          style: theme.textTheme.labelLarge?.copyWith(
            color: TarmeemColors.onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          onChanged: onChanged,
          inputFormatters: inputFormatters,
          maxLines: maxLines,
          minLines: minLines,
          readOnly: readOnly,
          enabled: enabled,
          autofocus: autofocus,
          textAlign: TextAlign.right,
          textDirection: textDirection ?? TextDirection.rtl,
          onTap: onTap,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: TarmeemColors.onSurface,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: theme.textTheme.bodyLarge?.copyWith(
              color: TarmeemColors.onSurfaceVariant.withOpacity(0.6),
            ),
            hintTextDirection: TextDirection.rtl,
            prefixIcon: prefixIcon,
            suffix: suffixWidget,
            filled: true,
            fillColor: enabled
                ? TarmeemColors.surfaceContainerLowest
                : TarmeemColors.surfaceContainerLow,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFFE5E7EB),
                width: 1.5,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: TarmeemColors.secondary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: TarmeemColors.error,
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: TarmeemColors.error,
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// A phone number input field with country code prefix.
class PhoneTextField extends StatelessWidget {
  const PhoneTextField({
    super.key,
    required this.controller,
    this.countryCode = '+966',
    this.countryFlag = '🇸🇦',
    this.onChanged,
    this.validator,
  });

  final TextEditingController controller;
  final String countryCode;
  final String countryFlag;
  final void Function(String)? onChanged;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.right,
      validator: validator,
      onChanged: onChanged,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: TarmeemColors.onSurface,
        letterSpacing: 1.2,
      ),
      decoration: InputDecoration(
        hintText: '50 123 4567',
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: TarmeemColors.onSurfaceVariant.withOpacity(0.5),
        ),
        filled: true,
        fillColor: TarmeemColors.surfaceContainerLowest,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB), width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide:
              const BorderSide(color: TarmeemColors.secondary, width: 1.5),
        ),
        // Country code prefix on the right side (RTL leading)
        suffixIcon: Container(
          margin: const EdgeInsets.only(right: 12, top: 8, bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: TarmeemColors.outlineVariant,
                width: 1,
              ),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                countryCode,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: TarmeemColors.onSurface,
                ),
              ),
              const SizedBox(width: 6),
              Text(countryFlag, style: const TextStyle(fontSize: 18)),
            ],
          ),
        ),
        prefixIcon: const Icon(
          Icons.phone_outlined,
          color: TarmeemColors.outline,
          size: 20,
        ),
      ),
    );
  }
}
