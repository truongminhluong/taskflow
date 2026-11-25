import 'package:flutter/material.dart';

class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.useMaterialDefaults = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool useMaterialDefaults;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        onPressed: isLoading ? null : onPressed,
        style: useMaterialDefaults
            ? null
            : FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                label,
                style: useMaterialDefaults
                    ? null
                    : const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
              ),
      ),
    );
  }
}
