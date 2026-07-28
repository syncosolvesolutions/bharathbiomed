import 'package:equatable/equatable.dart';

import 'permission.dart';

/// Field designations (MR -> ABM -> RBM -> ZBM) form a real parent/child
/// ladder via [Designation.parentDesignationId]/[Designation.hierarchyLevel].
/// Executive (CEO/COO) and Office Administration (Admin Manager, HR)
/// designations are organizationally parallel to that ladder, not its root —
/// they get scope through the `view_global_data` permission instead of tree
/// position, so they're modeled as their own categories rather than being
/// forced into a field-style parent chain.
enum DesignationCategory { field, officeAdministration, executive }

DesignationCategory designationCategoryFromString(String? value) {
  switch (value) {
    case 'office_administration':
      return DesignationCategory.officeAdministration;
    case 'executive':
      return DesignationCategory.executive;
    default:
      // Covers null and legacy docs written before category existed.
      return DesignationCategory.field;
  }
}

String designationCategoryToJson(DesignationCategory category) => switch (category) {
      DesignationCategory.field => 'field',
      DesignationCategory.officeAdministration => 'office_administration',
      DesignationCategory.executive => 'executive',
    };

extension DesignationCategoryLabel on DesignationCategory {
  String get label => switch (this) {
        DesignationCategory.field => 'Field',
        DesignationCategory.officeAdministration => 'Office Administration',
        DesignationCategory.executive => 'Executive',
      };
}

/// An admin-managed job title (e.g. "Medical Representative", "Area
/// Business Manager") assignable to an [Employee].
class Designation extends Equatable {
  final String id;
  final String name;
  final DesignationCategory category;

  /// 0 = top of the org, larger numbers = further down. Only meaningful for
  /// comparing designations within the same reporting ladder.
  final int hierarchyLevel;

  /// FK -> Designations/{id}, the designation this one directly reports to.
  /// Null for the top of a ladder, or for non-field categories (see
  /// [DesignationCategory] doc comment).
  final String? parentDesignationId;

  /// Raw [Permission.value] strings — kept as strings on the wire so an
  /// unrecognized value (e.g. a permission removed in a future release)
  /// parses safely instead of crashing; see [permissionSet].
  final List<String> permissions;

  const Designation({
    required this.id,
    required this.name,
    this.category = DesignationCategory.field,
    this.hierarchyLevel = 0,
    this.parentDesignationId,
    this.permissions = const [],
  });

  Set<Permission> get permissionSet => permissions.map(permissionFromString).whereType<Permission>().toSet();

  factory Designation.fromJson(String id, Map<String, dynamic> json) => Designation(
        id: id,
        name: json['name'] as String? ?? '',
        category: designationCategoryFromString(json['category'] as String?),
        hierarchyLevel: (json['hierarchyLevel'] as num?)?.toInt() ?? 0,
        parentDesignationId: json['parentDesignationId'] as String?,
        permissions: List<String>.from(json['permissions'] as List? ?? const []),
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'category': designationCategoryToJson(category),
        'hierarchyLevel': hierarchyLevel,
        'parentDesignationId': parentDesignationId,
        'permissions': permissions,
      };

  Designation copyWith({
    String? name,
    DesignationCategory? category,
    int? hierarchyLevel,
    String? Function()? parentDesignationId,
    List<String>? permissions,
  }) {
    return Designation(
      id: id,
      name: name ?? this.name,
      category: category ?? this.category,
      hierarchyLevel: hierarchyLevel ?? this.hierarchyLevel,
      parentDesignationId: parentDesignationId != null ? parentDesignationId() : this.parentDesignationId,
      permissions: permissions ?? this.permissions,
    );
  }

  @override
  List<Object?> get props => [id, name, category, hierarchyLevel, parentDesignationId, permissions];
}
