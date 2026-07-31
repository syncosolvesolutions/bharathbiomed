import 'dart:async';

import 'package:bharathbiomedpharma/core/auth/employee_login.dart';
import 'package:bharathbiomedpharma/data/repositories/admin_notifications_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/agency_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/auth_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/compliance_log_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/designation_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/doctor_change_request_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/doctor_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/doctor_visit_log_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/doctor_visit_plan_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/employee_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/entity_change_request_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/expense_claim_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/order_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/pharmacy_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/product_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/rcpa_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/reminder_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/sales_target_repository.dart';
import 'package:bharathbiomedpharma/data/repositories/usage_session_repository.dart';
import 'package:bharathbiomedpharma/domain/models/admin_notification.dart';
import 'package:bharathbiomedpharma/domain/models/agency.dart';
import 'package:bharathbiomedpharma/domain/models/compliance_log.dart';
import 'package:bharathbiomedpharma/domain/models/designation.dart';
import 'package:bharathbiomedpharma/domain/models/doctor.dart';
import 'package:bharathbiomedpharma/domain/models/doctor_change_request.dart';
import 'package:bharathbiomedpharma/domain/models/doctor_visit_log.dart';
import 'package:bharathbiomedpharma/domain/models/doctor_visit_plan.dart';
import 'package:bharathbiomedpharma/domain/models/employee.dart';
import 'package:bharathbiomedpharma/domain/models/entity_change_request.dart';
import 'package:bharathbiomedpharma/domain/models/expense_claim.dart';
import 'package:bharathbiomedpharma/domain/models/order.dart';
import 'package:bharathbiomedpharma/domain/models/permission.dart';
import 'package:bharathbiomedpharma/domain/models/pharmacy.dart';
import 'package:bharathbiomedpharma/domain/models/product.dart';
import 'package:bharathbiomedpharma/domain/models/product_batch.dart';
import 'package:bharathbiomedpharma/domain/models/rcpa_entry.dart';
import 'package:bharathbiomedpharma/domain/models/reminder.dart';
import 'package:bharathbiomedpharma/domain/models/sales_target.dart';
import 'package:bharathbiomedpharma/domain/models/usage_session.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Hand-rolled in-memory fakes for the repositories Phase 1's integration UI
/// tests drive through real screens. Each `implements` its real repository
/// directly (never calling its constructor, so none of this ever touches a
/// live Firebase/sqflite instance) and keeps enough state to make multi-step
/// flows ("submit an order, then see it pending, then approve it") behave
/// like the real thing — see the harness's doc comment for why this is
/// faked at the repository layer rather than the data-source layer.

class _Account {
  _Account({required this.password, required this.user, required this.disabled});
  final String password;
  final User user;
  final bool disabled;
}

class FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<User?>.broadcast();
  User? _currentUser;
  final Map<String, _Account> _accountsByEmail = {};

  /// [loginIdentifier] is whatever the user would type into the login
  /// field (an admin's real email, or an MR's plain username) — resolved
  /// through the same [resolveLoginEmail] the real repository uses, so
  /// tests can register an account the same way a real one would sign in.
  void registerAccount({
    required String loginIdentifier,
    required String password,
    required User user,
    bool disabled = false,
  }) {
    _accountsByEmail[resolveLoginEmail(loginIdentifier)] = _Account(password: password, user: user, disabled: disabled);
  }

  /// Seeds an already-signed-in session, for tests that start past the
  /// login screen (e.g. "an MR opens the app with an existing session").
  void seedSignedIn(User user) {
    _currentUser = user;
    _controller.add(user);
  }

  /// Real `FirebaseAuth.authStateChanges()` emits the current session
  /// immediately on subscription, then again on every change —
  /// `AuthController.build()` awaits `.first` on exactly this assumption. A
  /// plain broadcast stream never replays anything to a late subscriber, so
  /// this yields the current value up front before continuing from the
  /// broadcast controller.
  @override
  Stream<User?> authStateChanges() async* {
    yield _currentUser;
    yield* _controller.stream;
  }

  @override
  User? get currentUser => _currentUser;

  @override
  Future<User?> signIn(String identifier, String password) async {
    final account = _accountsByEmail[resolveLoginEmail(identifier)];
    if (account == null || account.password != password) {
      throw FirebaseAuthException(code: 'invalid-credential');
    }
    if (account.disabled) {
      throw FirebaseAuthException(code: 'user-disabled');
    }
    _currentUser = account.user;
    _controller.add(account.user);
    return account.user;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
    _controller.add(null);
  }

  @override
  Future<void> changePassword({required String currentPassword, required String newPassword}) async {}

  @override
  Future<void> sendPasswordResetEmail(String email) async {}
}

class FakeEmployeeRepository implements EmployeeRepository {
  final List<Employee> employees = [];

  @override
  Future<List<Employee>> fetchAll() async => List.of(employees);

  @override
  Future<List<Employee>> fetchDownline(String managerUid) async =>
      employees.where((e) => e.reportingChainUids.contains(managerUid)).toList();

  @override
  Stream<Employee?> watchMine(String uid) {
    final matches = employees.where((e) => e.uid == uid);
    return Stream.value(matches.isEmpty ? null : matches.first);
  }

  /// Own uid ever provided (there's no "current user" concept in a plain
  /// repository fake) — only meaningful for the one test that exercises
  /// this, which stubs it in directly rather than routing through
  /// [updateMyProfile]'s real signature (no uid parameter, mirroring the
  /// real Cloud Function's "acts on the caller" design).
  String? currentUid;

  @override
  Future<void> updateMyProfile({
    required String firstName,
    required String lastName,
    String? mobileNumber,
    String? photoUrl,
    String? dateOfBirth,
  }) async {
    final uid = currentUid;
    if (uid == null) return;
    final index = employees.indexWhere((e) => e.uid == uid);
    if (index == -1) return;
    final e = employees[index];
    employees[index] = Employee(
      uid: e.uid,
      username: e.username,
      firstName: firstName,
      lastName: lastName,
      designation: e.designation,
      areaName: e.areaName,
      mobileNumber: mobileNumber ?? e.mobileNumber,
      photoUrl: photoUrl ?? e.photoUrl,
      email: e.email,
      disabled: e.disabled,
      dateOfBirth: dateOfBirth ?? e.dateOfBirth,
      profileCompleted: true,
      designationId: e.designationId,
      managerId: e.managerId,
      reportingChainUids: e.reportingChainUids,
      permissions: e.permissions,
      hierarchyLevel: e.hierarchyLevel,
      category: e.category,
    );
  }

  int _counter = 0;

  @override
  Future<EmployeeCredentials> create({
    required String firstName,
    required String lastName,
    required String username,
    required String password,
    required String designation,
    required String areaName,
    required String email,
    String? mobileNumber,
    String? photoUrl,
    String? dateOfBirth,
    String? designationId,
    String? managerId,
  }) async {
    if (employees.any((e) => e.username == username)) {
      throw Exception('Username "$username" is already taken.');
    }
    final uid = 'employee-${_counter++}';
    employees.add(Employee(
      uid: uid,
      username: username,
      firstName: firstName,
      lastName: lastName,
      designation: designation,
      areaName: areaName,
      mobileNumber: mobileNumber,
      photoUrl: photoUrl,
      email: email,
      dateOfBirth: dateOfBirth,
      designationId: designationId,
      managerId: managerId,
    ));
    return EmployeeCredentials(username: username, loginEmail: email);
  }

  @override
  Future<EmployeeCredentials> update({
    required String uid,
    required String firstName,
    required String lastName,
    required String username,
    required String designation,
    required String areaName,
    required String email,
    String? mobileNumber,
    String? photoUrl,
    String? dateOfBirth,
    String? designationId,
    String? managerId,
  }) async {
    final index = employees.indexWhere((e) => e.uid == uid);
    if (index == -1) throw Exception('Employee not found.');
    final e = employees[index];
    employees[index] = Employee(
      uid: uid,
      username: username,
      firstName: firstName,
      lastName: lastName,
      designation: designation,
      areaName: areaName,
      mobileNumber: mobileNumber,
      photoUrl: photoUrl,
      email: email,
      disabled: e.disabled,
      dateOfBirth: dateOfBirth,
      profileCompleted: e.profileCompleted,
      designationId: designationId,
      managerId: managerId,
      reportingChainUids: e.reportingChainUids,
      permissions: e.permissions,
      hierarchyLevel: e.hierarchyLevel,
      category: e.category,
    );
    return EmployeeCredentials(username: username, loginEmail: email);
  }

  @override
  Future<void> delete(String uid) async => employees.removeWhere((e) => e.uid == uid);

  @override
  Future<void> resetPassword(String uid, String newPassword) async {}

  @override
  Future<void> setStatus(String uid, {required bool disabled}) async {
    final index = employees.indexWhere((e) => e.uid == uid);
    if (index == -1) return;
    final e = employees[index];
    employees[index] = Employee(
      uid: e.uid,
      username: e.username,
      firstName: e.firstName,
      lastName: e.lastName,
      designation: e.designation,
      areaName: e.areaName,
      mobileNumber: e.mobileNumber,
      photoUrl: e.photoUrl,
      email: e.email,
      disabled: disabled,
      dateOfBirth: e.dateOfBirth,
      profileCompleted: e.profileCompleted,
      designationId: e.designationId,
      managerId: e.managerId,
      reportingChainUids: e.reportingChainUids,
      permissions: e.permissions,
      hierarchyLevel: e.hierarchyLevel,
      category: e.category,
    );
  }
}

class FakeProductRepository implements ProductRepository {
  List<Product> products = [];
  List<String> departments = [];
  final List<ProductBatch> batches = [];
  int _batchCounter = 0;

  int stockFor(String productId) => products.firstWhere((p) => p.id == productId).stockQuantity;

  void setStock(String productId, int newStock) {
    final index = products.indexWhere((p) => p.id == productId);
    if (index == -1) return;
    final p = products[index];
    products[index] = Product(
      id: p.id,
      name: p.name,
      info: p.info,
      departments: p.departments,
      imageUrl: p.imageUrl,
      stockQuantity: newStock,
      unitPrice: p.unitPrice,
    );
  }

  @override
  Future<CatalogSnapshot> loadCachedCatalog() async => CatalogSnapshot(products: products, departments: departments);

  @override
  Future<CatalogSnapshot> sync() async => CatalogSnapshot(products: products, departments: departments);

  @override
  Future<bool> hasRemoteChanges() async => false;

  @override
  Future<CatalogSnapshot> fetchLiveCatalog() async => CatalogSnapshot(products: products, departments: departments);

  @override
  Future<String> createProduct({
    required String name,
    required String info,
    required Map<String, int> departments,
    required String imageUrl,
    double unitPrice = 0,
  }) async {
    final id = 'product-${products.length}';
    products.add(Product(id: id, name: name, info: info, departments: departments, imageUrl: imageUrl, unitPrice: unitPrice));
    return id;
  }

  @override
  Future<void> updateProduct(Product product) async {
    final index = products.indexWhere((p) => p.id == product.id);
    if (index != -1) products[index] = product;
  }

  @override
  Future<void> deleteProduct(String id) async => products.removeWhere((p) => p.id == id);

  @override
  Future<void> adjustStock(String productId, int delta) async => setStock(productId, stockFor(productId) + delta);

  @override
  Future<List<ProductBatch>> fetchBatches(String productId) async {
    final forProduct = batches.where((b) => b.productId == productId).toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return forProduct;
  }

  @override
  Future<void> addBatch(String productId,
      {required String batchNumber, required String expiryDate, required int quantity}) async {
    batches.add(ProductBatch(
      id: 'batch-${_batchCounter++}',
      productId: productId,
      batchNumber: batchNumber,
      expiryDate: expiryDate,
      quantity: quantity,
      createdAt: DateTime.now(),
    ));
    // A batch represents genuinely new stock arriving — moves the product's
    // stockQuantity total together with it, mirroring the real repository.
    setStock(productId, stockFor(productId) + quantity);
  }

  @override
  Future<void> deleteBatch(String productId, String batchId) async {
    final index = batches.indexWhere((b) => b.id == batchId && b.productId == productId);
    if (index == -1) return;
    final remaining = batches[index].quantity;
    batches.removeAt(index);
    if (remaining != 0) setStock(productId, stockFor(productId) - remaining);
  }

  @override
  Future<List<ProductBatch>> fetchExpiringWithinDays(int withinDays) async {
    final cutoff = DateTime.now().add(Duration(days: withinDays));
    String pad2(int n) => n.toString().padLeft(2, '0');
    final cutoffIso = '${cutoff.year.toString().padLeft(4, '0')}-${pad2(cutoff.month)}-${pad2(cutoff.day)}';
    final matches = batches.where((b) => b.expiryDate.compareTo(cutoffIso) <= 0).toList()
      ..sort((a, b) => a.expiryDate.compareTo(b.expiryDate));
    return matches;
  }

  @override
  Future<void> addDepartment(String name) async {
    if (!departments.contains(name)) departments.add(name);
  }

  @override
  Future<void> renameDepartment(String oldName, String newName) async {
    final index = departments.indexOf(oldName);
    if (index != -1) departments[index] = newName;
  }

  @override
  Future<void> deleteDepartment(String name) async => departments.remove(name);
}

class FakeAgencyRepository implements AgencyRepository {
  final List<Agency> agencies = [];

  @override
  Future<List<Agency>> loadCached() async => List.of(agencies);

  @override
  Future<List<Agency>> sync() async => List.of(agencies);

  @override
  Future<bool> hasRemoteChanges() async => false;

  @override
  Future<String> createAgency(Agency agency) async {
    agencies.add(agency);
    return agency.id;
  }

  @override
  Future<void> updateAgency(Agency agency) async {
    final index = agencies.indexWhere((a) => a.id == agency.id);
    if (index != -1) agencies[index] = agency;
  }

  @override
  Future<void> setActive(String id, {required bool active}) async {
    final index = agencies.indexWhere((a) => a.id == id);
    if (index != -1) agencies[index] = agencies[index].copyWith(active: active);
  }
}

class FakePharmacyRepository implements PharmacyRepository {
  final List<Pharmacy> pharmacies = [];

  @override
  Future<List<Pharmacy>> loadCached() async => List.of(pharmacies);

  @override
  Future<List<Pharmacy>> sync() async => List.of(pharmacies);

  @override
  Future<bool> hasRemoteChanges() async => false;

  @override
  Future<String> createPharmacy(Pharmacy pharmacy) async {
    pharmacies.add(pharmacy);
    return pharmacy.id;
  }

  @override
  Future<void> updatePharmacy(Pharmacy pharmacy) async {
    final index = pharmacies.indexWhere((p) => p.id == pharmacy.id);
    if (index != -1) pharmacies[index] = pharmacy;
  }

  @override
  Future<void> setActive(String id, {required bool active}) async {
    final index = pharmacies.indexWhere((p) => p.id == id);
    if (index != -1) pharmacies[index] = pharmacies[index].copyWith(active: active);
  }

  @override
  Future<List<Pharmacy>> loadLinkedToDoctor(String doctorId) async =>
      pharmacies.where((p) => p.linkedDoctorIds.contains(doctorId)).toList();
}

class FakeDoctorRepository implements DoctorRepository {
  final List<Doctor> doctors = [];
  int _counter = 0;

  @override
  Future<bool> hasCachedDoctors() async => doctors.isNotEmpty;

  @override
  Future<List<Doctor>> loadCached() async => List.of(doctors);

  @override
  Future<List<Doctor>> sync({String? mrUid}) async =>
      mrUid == null ? List.of(doctors) : doctors.where((d) => d.assignedMrUid == mrUid).toList();

  @override
  Future<bool> hasRemoteChanges({String? mrUid}) async => false;

  @override
  Future<String> createDoctor(Doctor doctor) async {
    final id = 'doctor-${_counter++}';
    doctors.add(Doctor(
      id: id,
      name: doctor.name,
      specialisation: doctor.specialisation,
      hospitalName: doctor.hospitalName,
      latitude: doctor.latitude,
      longitude: doctor.longitude,
      locationAddress: doctor.locationAddress,
      googleMapsLink: doctor.googleMapsLink,
      dateOfBirth: doctor.dateOfBirth,
      marriageAnniversary: doctor.marriageAnniversary,
      assignedMrUid: doctor.assignedMrUid,
      assignedMrName: doctor.assignedMrName,
      createdByUid: doctor.createdByUid,
      createdByName: doctor.createdByName,
    ));
    return id;
  }

  @override
  Future<void> updateDoctor(Doctor doctor) async {
    final index = doctors.indexWhere((d) => d.id == doctor.id);
    if (index != -1) doctors[index] = doctor;
  }

  @override
  Future<void> assignMr(String doctorId, {required String? mrUid, required String? mrName}) async {
    final index = doctors.indexWhere((d) => d.id == doctorId);
    if (index != -1) doctors[index] = doctors[index].copyWith(assignedMrUid: mrUid, assignedMrName: mrName);
  }

  @override
  Future<void> deleteDoctor(String id) async => doctors.removeWhere((d) => d.id == id);
}

class FakeDoctorChangeRequestRepository implements DoctorChangeRequestRepository {
  FakeDoctorChangeRequestRepository({required this.doctors});

  final FakeDoctorRepository doctors;
  final List<DoctorChangeRequest> requests = [];
  int _counter = 0;

  @override
  Future<void> submitCreate(Doctor proposed, {required String requestedByUid, required String requestedByName}) async {
    requests.add(DoctorChangeRequest(
      id: 'request-${_counter++}',
      type: DoctorChangeType.create,
      proposedData: DoctorChangeRequest.proposedDataFromDoctor(proposed),
      requestedByUid: requestedByUid,
      requestedByName: requestedByName,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<void> submitUpdate(Doctor proposed, {required String requestedByUid, required String requestedByName}) async {
    requests.add(DoctorChangeRequest(
      id: 'request-${_counter++}',
      type: DoctorChangeType.update,
      doctorId: proposed.id,
      proposedData: DoctorChangeRequest.proposedDataFromDoctor(proposed),
      requestedByUid: requestedByUid,
      requestedByName: requestedByName,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<int> countPendingUpload() async => 0;

  @override
  Future<void> uploadPending() async {}

  @override
  Future<List<DoctorChangeRequest>> fetchPending() async =>
      requests.where((r) => r.status == DoctorChangeStatus.pending).toList();

  @override
  Future<List<DoctorChangeRequest>> fetchMine(String requestedByUid) async =>
      requests.where((r) => r.requestedByUid == requestedByUid).toList();

  @override
  Future<void> review(String requestId, {required bool approve, String? reviewNote}) async {
    final index = requests.indexWhere((r) => r.id == requestId);
    if (index == -1) return;
    final request = requests[index];
    requests[index] = DoctorChangeRequest(
      id: request.id,
      type: request.type,
      doctorId: request.doctorId,
      proposedData: request.proposedData,
      requestedByUid: request.requestedByUid,
      requestedByName: request.requestedByName,
      status: approve ? DoctorChangeStatus.approved : DoctorChangeStatus.rejected,
      reviewNote: reviewNote,
      createdAt: request.createdAt,
    );
    if (!approve) return;

    // Mirrors what `reviewDoctorChangeRequest` (Cloud Function) does on
    // approval: write the proposed data straight into Doctors.
    final data = request.proposedData;
    final doctor = Doctor(
      id: request.doctorId ?? '',
      name: data['name'] as String? ?? '',
      specialisation: data['specialisation'] as String? ?? '',
      hospitalName: data['hospitalName'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      locationAddress: data['locationAddress'] as String?,
      googleMapsLink: data['googleMapsLink'] as String?,
      assignedMrUid: data['assignedMrUid'] as String?,
      assignedMrName: data['assignedMrName'] as String?,
      createdByUid: data['createdByUid'] as String?,
      createdByName: data['createdByName'] as String?,
    );
    if (request.type == DoctorChangeType.create) {
      await doctors.createDoctor(doctor);
    } else {
      await doctors.updateDoctor(doctor);
    }
  }
}

class FakeDoctorVisitPlanRepository implements DoctorVisitPlanRepository {
  final Map<String, DoctorVisitPlan> _plans = {};

  @override
  Future<DoctorVisitPlan> loadCached(String mrUid) async => _plans[mrUid] ?? DoctorVisitPlan(mrUid: mrUid);

  @override
  Future<DoctorVisitPlan> sync(String mrUid) async => _plans[mrUid] ?? DoctorVisitPlan(mrUid: mrUid);

  @override
  Future<void> save(DoctorVisitPlan plan) async => _plans[plan.mrUid] = plan;

  @override
  Future<bool> hasPendingUpload(String mrUid) async => false;

  @override
  Future<void> pushUnsynced(String mrUid) async {}

  @override
  Future<DoctorVisitPlan> submitForApproval(String mrUid) async {
    final pending = (_plans[mrUid] ?? DoctorVisitPlan(mrUid: mrUid)).copyAsPending();
    _plans[mrUid] = pending;
    return pending;
  }

  @override
  Future<List<DoctorVisitPlan>> fetchAllPending() async =>
      _plans.values.where((p) => p.status == VisitPlanStatus.pending).toList();

  @override
  Future<List<DoctorVisitPlan>> fetchPendingForEmployees(List<String> mrUids) async =>
      _plans.values.where((p) => mrUids.contains(p.mrUid) && p.status == VisitPlanStatus.pending).toList();

  @override
  Future<void> approve(String mrUid, {required String approvedByUid}) async {
    final plan = _plans[mrUid];
    if (plan == null) return;
    _plans[mrUid] = DoctorVisitPlan(
      mrUid: plan.mrUid,
      doctorIdsByWeekday: plan.doctorIdsByWeekday,
      status: VisitPlanStatus.approved,
      approvedByUid: approvedByUid,
      approvedAt: DateTime.now(),
    );
  }

  @override
  Future<void> reject(String mrUid, {required String approvedByUid, String? reason}) async {
    final plan = _plans[mrUid];
    if (plan == null) return;
    _plans[mrUid] = DoctorVisitPlan(
      mrUid: plan.mrUid,
      doctorIdsByWeekday: plan.doctorIdsByWeekday,
      status: VisitPlanStatus.rejected,
      approvedByUid: approvedByUid,
      rejectedReason: reason,
    );
  }
}

class FakeDoctorVisitLogRepository implements DoctorVisitLogRepository {
  final List<DoctorVisitLog> logs = [];
  int _counter = 0;

  @override
  Future<void> logVisit({
    required String mrUid,
    required String doctorId,
    required String doctorName,
    required String visitDate,
    required bool visited,
    required String feedback,
    double? latitude,
    double? longitude,
    Map<String, int> samplesGiven = const {},
  }) async {
    logs.add(DoctorVisitLog(
      id: 'log-${_counter++}',
      mrUid: mrUid,
      doctorId: doctorId,
      doctorName: doctorName,
      visitDate: visitDate,
      visited: visited,
      feedback: feedback,
      latitude: latitude,
      longitude: longitude,
      createdAt: DateTime.now(),
      samplesGiven: samplesGiven,
    ));
  }

  @override
  Future<List<DoctorVisitLog>> loadForMr(String mrUid) async => logs.where((l) => l.mrUid == mrUid).toList();

  @override
  Future<int> countPendingUpload() async => 0;

  @override
  Future<void> uploadPending() async {}

  @override
  Future<List<DoctorVisitLog>> fetchRecentForDashboard() async => List.of(logs);

  @override
  Future<List<DoctorVisitLog>> fetchRecentForEmployees(List<String> mrUids) async =>
      logs.where((l) => mrUids.contains(l.mrUid)).toList();
}

class FakeRcpaRepository implements RcpaRepository {
  final List<RcpaEntry> entries = [];

  @override
  Future<void> logEntry(RcpaEntry entry) async => entries.add(entry);

  @override
  Future<List<RcpaEntry>> loadForMr(String mrUid) async => entries.where((e) => e.mrUid == mrUid).toList();

  @override
  Future<int> countPendingUpload() async => 0;

  @override
  Future<void> uploadPending() async {}

  @override
  Future<List<RcpaEntry>> fetchRecentForDashboard() async => List.of(entries);

  @override
  Future<List<RcpaEntry>> fetchRecentForEmployees(List<String> mrUids) async =>
      entries.where((e) => mrUids.contains(e.mrUid)).toList();
}

class FakeSalesTargetRepository implements SalesTargetRepository {
  final Map<String, SalesTarget> _targets = {};

  @override
  Future<void> setTarget({
    required String employeeUid,
    required String period,
    required double targetValue,
    required String createdByUid,
  }) async {
    final id = '${employeeUid}_$period';
    _targets[id] =
        SalesTarget(id: id, employeeUid: employeeUid, period: period, targetValue: targetValue, createdByUid: createdByUid, createdAt: DateTime.now());
  }

  @override
  Future<SalesTarget?> fetchForEmployee(String employeeUid, String period) async => _targets['${employeeUid}_$period'];

  @override
  Future<List<SalesTarget>> fetchForEmployees(List<String> employeeUids, String period) async =>
      _targets.values.where((t) => employeeUids.contains(t.employeeUid) && t.period == period).toList();
}

/// [OrderRepository.dispatch] is a Cloud Function in production (a
/// transactional stock decrement) — this fake reproduces the same
/// observable behavior (reject if any line exceeds current stock, else
/// decrement) directly against [products], the same [FakeProductRepository]
/// instance the test's `productRepositoryProvider` override uses, so
/// dispatch-driven stock changes actually show up in the catalog.
class FakeOrderRepository implements OrderRepository {
  FakeOrderRepository({required this.products});

  final FakeProductRepository products;
  final List<Order> orders = [];
  int _counter = 0;

  @override
  Future<void> submit(Order order) async {
    orders.add(Order(
      id: 'order-${_counter++}',
      agencyId: order.agencyId,
      agencyName: order.agencyName,
      createdByUid: order.createdByUid,
      createdByName: order.createdByName,
      items: order.items,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<int> countPendingUpload() async => 0;

  @override
  Future<void> uploadPending() async {}

  @override
  Future<List<Order>> fetchMine(String createdByUid) async => orders.where((o) => o.createdByUid == createdByUid).toList();

  @override
  Future<List<Order>> fetchAll() async => List.of(orders);

  @override
  Future<List<Order>> fetchForEmployees(List<String> employeeUids) async =>
      orders.where((o) => employeeUids.contains(o.createdByUid)).toList();

  @override
  Future<void> approve(String orderId, {required String approvedByUid}) async =>
      _replace(orderId, (o) => _withStatus(o, OrderStatus.approved, approvedByUid: approvedByUid, approvedAt: DateTime.now()));

  @override
  Future<void> reject(String orderId, {required String approvedByUid, String? reason}) async => _replace(
      orderId,
      (o) =>
          _withStatus(o, OrderStatus.rejected, approvedByUid: approvedByUid, approvedAt: DateTime.now(), rejectedReason: reason));

  @override
  Future<void> dispatch(String orderId) async {
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index == -1) throw Exception('Order not found.');
    final order = orders[index];
    if (order.status != OrderStatus.approved) {
      throw Exception('Only an approved order can be dispatched.');
    }
    for (final item in order.items) {
      if (products.stockFor(item.productId) < item.quantity) {
        throw Exception('Insufficient stock for ${item.productName}.');
      }
    }
    for (final item in order.items) {
      products.setStock(item.productId, products.stockFor(item.productId) - item.quantity);
    }
    orders[index] = _withStatus(order, OrderStatus.dispatched, dispatchedAt: DateTime.now());
  }

  @override
  Future<void> markDelivered(String orderId) async =>
      _replace(orderId, (o) => _withStatus(o, OrderStatus.delivered, deliveredAt: DateTime.now()));

  void _replace(String orderId, Order Function(Order) update) {
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index != -1) orders[index] = update(orders[index]);
  }

  Order _withStatus(
    Order order,
    OrderStatus status, {
    String? approvedByUid,
    DateTime? approvedAt,
    String? rejectedReason,
    DateTime? dispatchedAt,
    DateTime? deliveredAt,
  }) {
    return Order(
      id: order.id,
      agencyId: order.agencyId,
      agencyName: order.agencyName,
      createdByUid: order.createdByUid,
      createdByName: order.createdByName,
      items: order.items,
      status: status,
      approvedByUid: approvedByUid ?? order.approvedByUid,
      approvedAt: approvedAt ?? order.approvedAt,
      rejectedReason: rejectedReason ?? order.rejectedReason,
      dispatchedByUid: order.dispatchedByUid,
      dispatchedAt: dispatchedAt ?? order.dispatchedAt,
      deliveredAt: deliveredAt ?? order.deliveredAt,
      createdAt: order.createdAt,
    );
  }
}

/// `unreadAdminNotificationsCountProvider` reads `.value` straight off the
/// stream this backs (not `.valueOrNull`), which rethrows if the provider
/// is in an error state — so the admin home screen's bell icon needs a
/// working fake even though Phase 1 never asserts on notification content.
class FakeAdminNotificationsRepository implements AdminNotificationsRepository {
  @override
  Stream<List<AdminNotification>> watchAll() => Stream.value(const []);

  @override
  Future<void> markRead(String id) async {}
}

/// Mirrors [FakeOrderRepository] minus the dispatch step — a claim's
/// lifecycle stops at approved/rejected (see [ExpenseClaim]'s doc comment).
class FakeExpenseClaimRepository implements ExpenseClaimRepository {
  final List<ExpenseClaim> claims = [];
  int _counter = 0;

  @override
  Future<void> submit(ExpenseClaim claim) async {
    claims.add(ExpenseClaim(
      id: 'claim-${_counter++}',
      mrUid: claim.mrUid,
      mrName: claim.mrName,
      category: claim.category,
      claimDate: claim.claimDate,
      amount: claim.amount,
      description: claim.description,
      receiptPhotoUrl: claim.receiptPhotoUrl,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<int> countPendingUpload() async => 0;

  @override
  Future<void> uploadPending() async {}

  @override
  Future<List<ExpenseClaim>> fetchMine(String mrUid) async => claims.where((c) => c.mrUid == mrUid).toList();

  @override
  Future<List<ExpenseClaim>> fetchAll() async => List.of(claims);

  @override
  Future<List<ExpenseClaim>> fetchForEmployees(List<String> mrUids) async =>
      claims.where((c) => mrUids.contains(c.mrUid)).toList();

  @override
  Future<void> approve(String claimId, {required String approvedByUid}) async =>
      _setStatus(claimId, ExpenseClaimStatus.approved, approvedByUid: approvedByUid);

  @override
  Future<void> reject(String claimId, {required String approvedByUid, String? reason}) async =>
      _setStatus(claimId, ExpenseClaimStatus.rejected, approvedByUid: approvedByUid, rejectedReason: reason);

  void _setStatus(String claimId, ExpenseClaimStatus status, {String? approvedByUid, String? rejectedReason}) {
    final index = claims.indexWhere((c) => c.id == claimId);
    if (index == -1) return;
    final c = claims[index];
    claims[index] = ExpenseClaim(
      id: c.id,
      mrUid: c.mrUid,
      mrName: c.mrName,
      category: c.category,
      claimDate: c.claimDate,
      amount: c.amount,
      description: c.description,
      receiptPhotoUrl: c.receiptPhotoUrl,
      status: status,
      approvedByUid: approvedByUid ?? c.approvedByUid,
      approvedAt: DateTime.now(),
      rejectedReason: rejectedReason ?? c.rejectedReason,
      createdAt: c.createdAt,
    );
  }
}

/// Mirrors [FakeRcpaRepository] exactly — append-only, no approval step.
class FakeComplianceLogRepository implements ComplianceLogRepository {
  final List<ComplianceLog> logs = [];

  @override
  Future<void> logEntry(ComplianceLog log) async => logs.add(log);

  @override
  Future<List<ComplianceLog>> loadForMr(String mrUid) async => logs.where((l) => l.mrUid == mrUid).toList();

  @override
  Future<int> countPendingUpload() async => 0;

  @override
  Future<void> uploadPending() async {}

  @override
  Future<List<ComplianceLog>> fetchRecentForDashboard() async => List.of(logs);

  @override
  Future<List<ComplianceLog>> fetchRecentForEmployees(List<String> mrUids) async =>
      logs.where((l) => mrUids.contains(l.mrUid)).toList();
}

/// Mirrors [FakeDoctorChangeRequestRepository], generalized over
/// [EntityType]: on approval, writes the proposed data straight into
/// whichever of [agencies]/[pharmacies] the request is for, the same way
/// `reviewEntityChangeRequest` (Cloud Function) does in production.
class FakeEntityChangeRequestRepository implements EntityChangeRequestRepository {
  FakeEntityChangeRequestRepository({required this.agencies, required this.pharmacies});

  final FakeAgencyRepository agencies;
  final FakePharmacyRepository pharmacies;
  final List<EntityChangeRequest> requests = [];
  int _counter = 0;

  @override
  Future<void> submitAgency(Agency proposed, {required String requestedByUid, required String requestedByName}) async {
    requests.add(EntityChangeRequest(
      id: 'entity-request-${_counter++}',
      entityType: EntityType.agency,
      type: EntityChangeType.create,
      proposedData: proposed.toJson()..remove('id'),
      requestedByUid: requestedByUid,
      requestedByName: requestedByName,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<void> submitPharmacy(Pharmacy proposed,
      {required String requestedByUid, required String requestedByName}) async {
    requests.add(EntityChangeRequest(
      id: 'entity-request-${_counter++}',
      entityType: EntityType.pharmacy,
      type: EntityChangeType.create,
      proposedData: proposed.toJson()..remove('id'),
      requestedByUid: requestedByUid,
      requestedByName: requestedByName,
      createdAt: DateTime.now(),
    ));
  }

  @override
  Future<int> countPendingUpload() async => 0;

  @override
  Future<void> uploadPending() async {}

  @override
  Future<List<EntityChangeRequest>> fetchPending() async =>
      requests.where((r) => r.status == EntityChangeStatus.pending).toList();

  @override
  Future<List<EntityChangeRequest>> fetchMine(String requestedByUid) async =>
      requests.where((r) => r.requestedByUid == requestedByUid).toList();

  @override
  Future<void> review(String requestId, {required bool approve, String? reviewNote}) async {
    final index = requests.indexWhere((r) => r.id == requestId);
    if (index == -1) return;
    final request = requests[index];
    requests[index] = EntityChangeRequest(
      id: request.id,
      entityType: request.entityType,
      type: request.type,
      entityId: request.entityId,
      proposedData: request.proposedData,
      requestedByUid: request.requestedByUid,
      requestedByName: request.requestedByName,
      status: approve ? EntityChangeStatus.approved : EntityChangeStatus.rejected,
      reviewNote: reviewNote,
      createdAt: request.createdAt,
    );
    if (!approve) return;

    final data = request.proposedData;
    if (request.entityType == EntityType.agency) {
      await agencies.createAgency(Agency.fromJson('agency-${_counter++}', data));
    } else {
      await pharmacies.createPharmacy(Pharmacy.fromJson('pharmacy-${_counter++}', data));
    }
  }
}

/// Skips the real repository's first-run default-designation seeding
/// ([DesignationRepository.fetchAll]'s `defaultDesignations` fallback) and
/// the downline-reassignment bookkeeping in `save` — tests seed whatever
/// designations a scenario needs directly on [designations] instead.
class FakeDesignationRepository implements DesignationRepository {
  final List<Designation> designations = [];
  int _counter = 0;

  @override
  Future<List<Designation>> fetchAll() async => List.of(designations);

  @override
  Future<String> save({
    String? id,
    required String name,
    required DesignationCategory category,
    required int hierarchyLevel,
    String? parentDesignationId,
    required Set<Permission> permissions,
    required Set<String> downlineDesignationIds,
  }) async {
    if (designations.any((d) => d.id != id && d.name.toLowerCase() == name.toLowerCase())) {
      throw Exception('A designation named "$name" already exists.');
    }
    final resolvedId = id ?? 'designation-${_counter++}';
    final designation = Designation(
      id: resolvedId,
      name: name,
      category: category,
      hierarchyLevel: hierarchyLevel,
      parentDesignationId: parentDesignationId,
      permissions: permissions.map((p) => p.value).toList(),
    );
    final index = designations.indexWhere((d) => d.id == resolvedId);
    if (index == -1) {
      designations.add(designation);
    } else {
      designations[index] = designation;
    }
    return resolvedId;
  }

  @override
  Future<void> delete(String id) async => designations.removeWhere((d) => d.id == id);
}

/// [UsageDashboardController] only ever calls the two "recent" fetches
/// (never `startSession`/`closeSession`, which only the real app-lifecycle
/// hooks trigger) — tests seed [sessions] directly to represent "what's
/// already been uploaded".
class FakeUsageSessionRepository implements UsageSessionRepository {
  final List<UsageSession> sessions = [];

  @override
  Future<String> startSession({
    required String employeeUid,
    required String username,
    double? latitude,
    double? longitude,
  }) async =>
      throw UnimplementedError('not exercised by these flows');

  @override
  Future<void> closeSession(String id) async {}

  @override
  Future<int> countPendingUpload() async => 0;

  @override
  Future<void> uploadPending() async {}

  @override
  Future<List<UsageSession>> fetchRecentForDashboard() async => List.of(sessions);

  @override
  Future<List<UsageSession>> fetchRecentForEmployees(List<String> employeeUids) async =>
      sessions.where((s) => employeeUids.contains(s.employeeUid)).toList();
}

/// [myRemindersProvider] is a `StreamProvider` reading straight off
/// [watchFor] — mirrors [FakeAuthRepository.authStateChanges]'s need to
/// yield the *current* state immediately on subscription (a plain broadcast
/// stream never replays to a late listener), then again on every
/// create/complete/delete.
class FakeReminderRepository implements ReminderRepository {
  final List<Reminder> reminders = [];
  final _changes = StreamController<void>.broadcast();
  int _counter = 0;

  List<Reminder> _forOwner(String ownerUid) => reminders.where((r) => r.ownerUid == ownerUid).toList();

  @override
  Stream<List<Reminder>> watchFor(String ownerUid) async* {
    yield _forOwner(ownerUid);
    yield* _changes.stream.map((_) => _forOwner(ownerUid));
  }

  @override
  Future<void> create(Reminder reminder) async {
    reminders.add(Reminder(
      id: 'reminder-${_counter++}',
      ownerUid: reminder.ownerUid,
      ownerName: reminder.ownerName,
      createdByUid: reminder.createdByUid,
      createdByName: reminder.createdByName,
      title: reminder.title,
      note: reminder.note,
      dueAt: reminder.dueAt,
      createdAt: DateTime.now(),
    ));
    _changes.add(null);
  }

  @override
  Future<void> setCompleted(String id, bool completed) async {
    final index = reminders.indexWhere((r) => r.id == id);
    if (index == -1) return;
    final r = reminders[index];
    reminders[index] = Reminder(
      id: r.id,
      ownerUid: r.ownerUid,
      ownerName: r.ownerName,
      createdByUid: r.createdByUid,
      createdByName: r.createdByName,
      title: r.title,
      note: r.note,
      dueAt: r.dueAt,
      completed: completed,
      createdAt: r.createdAt,
    );
    _changes.add(null);
  }

  @override
  Future<void> delete(String id) async {
    reminders.removeWhere((r) => r.id == id);
    _changes.add(null);
  }
}
