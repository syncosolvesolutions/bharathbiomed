import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quickalert/quickalert.dart';

import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/utils/validators.dart';
import '../../domain/models/designation.dart';
import '../../domain/models/permission.dart';
import 'designation_controller.dart';

/// Add or edit a designation — title, where it sits in the org (category +
/// numeric level + who it reports to), which other designations report to
/// it, and which permissions it grants. `designation == null` means "add".
class DesignationFormScreen extends ConsumerStatefulWidget {
  const DesignationFormScreen({super.key, this.designation});

  final Designation? designation;

  @override
  ConsumerState<DesignationFormScreen> createState() => _DesignationFormScreenState();
}

class _DesignationFormScreenState extends ConsumerState<DesignationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.designation?.name);
  late final _levelController =
      TextEditingController(text: (widget.designation?.hierarchyLevel ?? 0).toString());

  late DesignationCategory _category = widget.designation?.category ?? DesignationCategory.field;
  late String? _parentDesignationId = widget.designation?.parentDesignationId;
  final Set<Permission> _permissions = {};
  late Set<String> _downlineDesignationIds = {};
  bool _saving = false;
  bool _downlineLoaded = false;

  bool get _isEditing => widget.designation != null;

  @override
  void initState() {
    super.initState();
    _permissions.addAll(widget.designation?.permissionSet ?? const {});
  }

  @override
  void dispose() {
    debugPrint('DesignationFormScreen.dispose: disposing');
    _nameController.dispose();
    _levelController.dispose();
    super.dispose();
  }

  int? get _parsedLevel => int.tryParse(_levelController.text.trim());

  Future<void> _save() async {
    debugPrint('DesignationFormScreen._save: save requested isEditing=$_isEditing');
    if (!_formKey.currentState!.validate()) return;
    final level = _parsedLevel;
    if (level == null) return;

    setState(() => _saving = true);
    try {
      await ref.read(designationControllerProvider.notifier).save(
            id: widget.designation?.id,
            name: _nameController.text.trim(),
            category: _category,
            hierarchyLevel: level,
            parentDesignationId: _category == DesignationCategory.field ? _parentDesignationId : null,
            permissions: _permissions,
            downlineDesignationIds: _downlineDesignationIds,
          );
      debugPrint('DesignationFormScreen._save: save succeeded');
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (error, stackTrace) {
      debugPrint('DesignationFormScreen._save: save failed error=$error');
      AppLogger.error('DesignationForm', 'save failed', error: error, stackTrace: stackTrace);
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: _isEditing ? 'Failed to update designation' : 'Failed to add designation',
        text: UserFacingError.describe(error),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final designationsAsync = ref.watch(designationControllerProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Designation' : 'Add Designation')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => Validators.required(value, fieldLabel: 'title'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<DesignationCategory>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items: DesignationCategory.values
                    .map((c) => DropdownMenuItem(value: c, child: Text(c.label)))
                    .toList(),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _category = value;
                    if (value != DesignationCategory.field) _parentDesignationId = null;
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _levelController,
                decoration: const InputDecoration(
                  labelText: 'Hierarchy Level',
                  helperText: '0 = top of the org, larger numbers = further down.',
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                validator: (value) => int.tryParse((value ?? '').trim()) == null ? 'Enter a whole number' : null,
              ),
              const SizedBox(height: 12),
              designationsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => Text('Failed to load designations: ${UserFacingError.describe(error)}'),
                data: (items) {
                  if (!_downlineLoaded) {
                    _downlineDesignationIds = items
                        .where((d) => widget.designation != null && d.parentDesignationId == widget.designation!.id)
                        .map((d) => d.id)
                        .toSet();
                    _downlineLoaded = true;
                  }
                  final level = _parsedLevel;
                  final others = items.where((d) => d.id != widget.designation?.id).toList();

                  final children = <Widget>[];
                  if (_category == DesignationCategory.field) {
                    final parentOptions =
                        others.where((d) => level == null || d.hierarchyLevel < level).toList();
                    children.addAll([
                      DropdownButtonFormField<String?>(
                        initialValue: parentOptions.any((d) => d.id == _parentDesignationId)
                            ? _parentDesignationId
                            : null,
                        decoration: const InputDecoration(labelText: 'Reports To (Parent Designation)'),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('None (top of ladder)')),
                          ...parentOptions.map((d) => DropdownMenuItem(value: d.id, child: Text(d.name))),
                        ],
                        onChanged: (value) => setState(() => _parentDesignationId = value),
                      ),
                      const SizedBox(height: 16),
                    ]);
                  }

                  children.add(Text('Reports to this designation', style: Theme.of(context).textTheme.titleSmall));
                  if (!_isEditing) {
                    children.add(const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Save first, then choose who reports to this designation.',
                          style: TextStyle(fontStyle: FontStyle.italic)),
                    ));
                  } else if (others.isEmpty) {
                    children.add(const Text('No other designations yet.'));
                  } else {
                    children.addAll(others.map((d) => CheckboxListTile(
                          dense: true,
                          title: Text(d.name),
                          value: _downlineDesignationIds.contains(d.id),
                          onChanged: (checked) => setState(() {
                            if (checked ?? false) {
                              _downlineDesignationIds.add(d.id);
                            } else {
                              _downlineDesignationIds.remove(d.id);
                            }
                          }),
                        )));
                  }

                  return Column(crossAxisAlignment: CrossAxisAlignment.start, children: children);
                },
              ),
              const SizedBox(height: 16),
              Text('Permissions', style: Theme.of(context).textTheme.titleSmall),
              ...Permission.values.map((permission) => CheckboxListTile(
                    dense: true,
                    title: Text(permission.label),
                    value: _permissions.contains(permission),
                    onChanged: (checked) => setState(() {
                      if (checked ?? false) {
                        _permissions.add(permission);
                      } else {
                        _permissions.remove(permission);
                      }
                    }),
                  )),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(_isEditing ? 'Update Designation' : 'Add Designation'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
