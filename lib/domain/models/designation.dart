import 'package:equatable/equatable.dart';

/// An admin-managed job title (e.g. "Medical Representative", "Area
/// Business Manager") assignable to an [Employee].
class Designation extends Equatable {
  final String id;
  final String name;

  const Designation({required this.id, required this.name});

  @override
  List<Object?> get props => [id, name];
}
