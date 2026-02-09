import 'package:flutter/material.dart';

class ChecklistItem extends StatelessWidget {
  const ChecklistItem({
    super.key,
    required this.title,
    required this.checked,
    required this.onChanged,
  });

  final String title;
  final bool checked;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: CheckboxListTile(
        value: checked,
        onChanged: onChanged,
        title: Text(title),
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}
