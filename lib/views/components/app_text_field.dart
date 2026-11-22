import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:sewa_garasi/core/constants/app_colors.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.inputFormatters,
    this.onChanged,
    this.suffix,
    this.maxLength,
    this.prefixIcon,
  });

  final String label;
  final TextEditingController? controller;
  final String? hint;
  final String? Function(String?)? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final Widget? suffix;
  final int? maxLength;
  final IconData? prefixIcon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboardType,
        obscureText: obscureText,
        readOnly: readOnly,
        enabled: enabled,
        inputFormatters: inputFormatters,
        onChanged: onChanged,
        maxLength: maxLength,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          suffixIcon: suffix,
          prefixIcon: prefixIcon == null ? null : Icon(prefixIcon, size: 20),
          counterText: '',
        ),
      ),
    );
  }
}

class AppDropdownField<T> extends StatelessWidget {
  const AppDropdownField({
    super.key,
    required this.label,
    required this.items,
    required this.itemLabel,
    required this.value,
    required this.onChanged,
    this.validator,
    this.enabled = true,
    this.helperText,
  });

  final String label;
  final List<T> items;
  final String Function(T) itemLabel;
  final T? value;
  final ValueChanged<T?> onChanged;
  final String? Function(T?)? validator;
  final bool enabled;

  final String? helperText;

  bool get _locked => items.length == 1 && value == items.first;

  Future<void> _pick(BuildContext context, FormFieldState<T> field) async {
    final picked = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Text('Belum ada pilihan.',
                      style: TextStyle(color: AppColors.textSecondary)),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.only(bottom: 12),
                  children: [
                    for (final item in items)
                      ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 20),
                        title: Text(itemLabel(item)),
                        trailing: item == value
                            ? const Icon(Icons.check_circle,
                                color: AppColors.primary)
                            : null,
                        selected: item == value,
                        onTap: () => Navigator.pop(sheetContext, item),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || picked == value) return;
    field.didChange(picked);
    onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: FormField<T>(
        key: ValueKey<Object?>(value),
        initialValue: value,
        validator: validator,
        builder: (field) => InkWell(
          onTap: enabled && !_locked ? () => _pick(context, field) : null,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              errorText: field.errorText,
              helperText: helperText,
              helperMaxLines: 3,
              enabled: enabled,
              suffixIcon: Icon(
                _locked ? Icons.lock_outline : Icons.expand_more,
                size: _locked ? 20 : null,
              ),
            ),
            isEmpty: value == null,
            child: Text(
              value == null ? '' : itemLabel(value as T),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
  }
}
