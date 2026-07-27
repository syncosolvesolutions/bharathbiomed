import 'package:flutter/material.dart';

/// Editable list of every department with a numeric "position" field. A
/// position of 0 means "not shown in this department" — only departments
/// with a position greater than 0 end up in the product's `departments` map
/// (see ProductFormScreen._save), which also controls display order within
/// that department (lower sorts first).
class DepartmentPositionEditor extends StatelessWidget {
  const DepartmentPositionEditor({
    super.key,
    required this.departments,
    required this.positions,
    required this.onChanged,
  });

  final List<String> departments;
  final Map<String, int> positions;
  final void Function(String department, int position) onChanged;

  @override
  Widget build(BuildContext context) {
    if (departments.isEmpty) {
      return const Text('No departments yet — add one from Manage Departments first.');
    }

    return Column(
      children: departments.map((department) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(department, style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Expanded(
                child: TextFormField(
                  key: ValueKey(department),
                  initialValue: (positions[department] ?? 0).toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Position', border: OutlineInputBorder()),
                  onChanged: (value) => onChanged(department, int.tryParse(value) ?? 0),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
