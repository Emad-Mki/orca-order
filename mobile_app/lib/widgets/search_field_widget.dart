import 'package:flutter/material.dart';

/// حقل بحث مع أيقونة وميزات متقدمة
class SearchFieldWidget extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final VoidCallback? onClear;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final TextInputAction textInputAction;

  const SearchFieldWidget({
    super.key,
    required this.controller,
    this.hintText = 'ابحث...',
    this.onClear,
    this.onChanged,
    this.autofocus = false,
    this.textInputAction = TextInputAction.search,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        textInputAction: textInputAction,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    controller.clear();
                    onClear?.call();
                  },
                )
              : null,
          border: const OutlineInputBorder(),
          filled: true,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
