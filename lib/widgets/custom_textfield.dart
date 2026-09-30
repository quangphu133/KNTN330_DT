import 'package:flutter/material.dart';

class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.minLines = 1,
    this.maxLines = 1,
    this.onChanged,
    this.readOnly = false,
    this.onTap,
    this.suffixIcon,
  });

  final TextEditingController? controller;
  final String label;
  final String? hint;
  final Widget? prefixIcon;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final int minLines;
  final int maxLines;
  final ValueChanged<String>? onChanged;
  final bool readOnly;
  final VoidCallback? onTap;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      obscureText: obscureText,
      minLines: minLines,
      maxLines: maxLines,
      onChanged: onChanged,
      readOnly: readOnly,
      onTap: onTap,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: prefixIcon,
        suffixIcon: suffixIcon,
      ),
    );
  }
}
