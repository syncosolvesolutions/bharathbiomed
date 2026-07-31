import 'package:bharathbiomedpharma/domain/models/agency.dart';
import 'package:bharathbiomedpharma/domain/models/compliance_log.dart';
import 'package:bharathbiomedpharma/domain/models/designation.dart';
import 'package:bharathbiomedpharma/domain/models/doctor.dart';
import 'package:bharathbiomedpharma/domain/models/employee.dart';
import 'package:bharathbiomedpharma/domain/models/permission.dart';
import 'package:bharathbiomedpharma/domain/models/pharmacy.dart';
import 'package:bharathbiomedpharma/domain/models/product.dart';
import 'package:bharathbiomedpharma/domain/models/product_batch.dart';
import 'package:bharathbiomedpharma/domain/models/usage_session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:mocktail/mocktail.dart';

/// Builders for the domain models Phase 1's integration flows need, mirroring
/// the real constructors in `lib/domain/models/*` so tests read like plain
/// data setup instead of re-deriving field lists.
class MockFirebaseUser extends Mock implements User {}

/// A `firebase_auth` [User] double — real `User` pulls in platform channels
/// mocktail's [Mock] never touches, so this is safe to construct in a plain
/// widget test.
User buildFirebaseUser({required String uid, String? email}) {
  final user = MockFirebaseUser();
  when(() => user.uid).thenReturn(uid);
  when(() => user.email).thenReturn(email);
  return user;
}

Employee buildEmployee({
  required String uid,
  required String username,
  String firstName = 'Test',
  String lastName = 'User',
  String designation = 'Medical Representative',
  String areaName = 'Test Area',
  String? email,
  bool disabled = false,
  bool profileCompleted = true,
  String? managerId,
  List<String> reportingChainUids = const [],
  List<String> permissions = const [],
  String? category,
  int? hierarchyLevel,
  String? dateOfBirth,
  String? photoUrl,
}) {
  return Employee(
    uid: uid,
    username: username,
    firstName: firstName,
    lastName: lastName,
    designation: designation,
    areaName: areaName,
    email: email,
    disabled: disabled,
    profileCompleted: profileCompleted,
    managerId: managerId,
    reportingChainUids: reportingChainUids,
    permissions: permissions,
    category: category,
    hierarchyLevel: hierarchyLevel,
    dateOfBirth: dateOfBirth,
    photoUrl: photoUrl,
  );
}

Product buildProduct({
  required String id,
  String name = 'Test Product',
  String info = 'Test info',
  Map<String, int> departments = const {'General': 0},
  // Deliberately not a real (or fake-but-real-looking) http(s) URL:
  // `CachedNetworkImage` would attempt a genuine network fetch for one,
  // which never resolves in the sandboxed test network and leaves its
  // indeterminate loading spinner running forever — that alone is enough
  // to make `pumpAndSettle` hang. An empty string fails to parse
  // immediately instead, landing straight on `errorWidget`.
  String imageUrl = '',
  int stockQuantity = 100,
  double unitPrice = 10,
}) {
  return Product(
    id: id,
    name: name,
    info: info,
    departments: departments,
    imageUrl: imageUrl,
    stockQuantity: stockQuantity,
    unitPrice: unitPrice,
  );
}

Agency buildAgency({
  required String id,
  String name = 'Test Agency',
  String contactPerson = 'Contact Person',
  String phone = '9999999999',
  bool active = true,
}) {
  return Agency(id: id, name: name, contactPerson: contactPerson, phone: phone, active: active);
}

Pharmacy buildPharmacy({
  required String id,
  String name = 'Test Pharmacy',
  bool active = true,
  List<String> linkedDoctorIds = const [],
}) {
  return Pharmacy(id: id, name: name, active: active, linkedDoctorIds: linkedDoctorIds);
}

Designation buildDesignation({
  required String id,
  String name = 'Medical Representative',
  DesignationCategory category = DesignationCategory.field,
  int hierarchyLevel = 0,
  String? parentDesignationId,
  Set<Permission> permissions = const {},
}) {
  return Designation(
    id: id,
    name: name,
    category: category,
    hierarchyLevel: hierarchyLevel,
    parentDesignationId: parentDesignationId,
    permissions: permissions.map((p) => p.value).toList(),
  );
}

Doctor buildDoctor({
  required String id,
  String name = 'Dr. Test',
  String specialisation = 'General Medicine',
  String hospitalName = 'Test Hospital',
  String? locationAddress = 'Test address',
  String? assignedMrUid,
  String? assignedMrName,
}) {
  return Doctor(
    id: id,
    name: name,
    specialisation: specialisation,
    hospitalName: hospitalName,
    locationAddress: locationAddress,
    assignedMrUid: assignedMrUid,
    assignedMrName: assignedMrName,
  );
}

ProductBatch buildProductBatch({
  required String id,
  required String productId,
  String batchNumber = 'B-1',
  required String expiryDate,
  int quantity = 10,
}) {
  return ProductBatch(id: id, productId: productId, batchNumber: batchNumber, expiryDate: expiryDate, quantity: quantity);
}

ComplianceLog buildComplianceLog({
  required String id,
  required String mrUid,
  String mrName = 'Test MR',
  required String doctorId,
  required String doctorName,
  ComplianceCategory category = ComplianceCategory.gift,
  String description = '',
  required double value,
  String? logDate,
  DateTime? createdAt,
}) {
  final now = createdAt ?? DateTime.now();
  return ComplianceLog(
    id: id,
    mrUid: mrUid,
    mrName: mrName,
    doctorId: doctorId,
    doctorName: doctorName,
    category: category,
    description: description,
    value: value,
    logDate: logDate ?? '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
    createdAt: now,
  );
}

UsageSession buildUsageSession({
  required String id,
  required String employeeUid,
  String username = 'test_user',
  required DateTime openedAt,
  DateTime? closedAt,
  double? latitude,
  double? longitude,
}) {
  return UsageSession(
    id: id,
    employeeUid: employeeUid,
    username: username,
    openedAt: openedAt,
    closedAt: closedAt,
    latitude: latitude,
    longitude: longitude,
  );
}
