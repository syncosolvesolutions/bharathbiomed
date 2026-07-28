import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/utils/date_of_birth.dart';
import '../../domain/models/doctor.dart';
import '../admin/admin_access.dart';
import 'visit_log_dialog.dart';

class DoctorDetailScreen extends ConsumerWidget {
  const DoctorDetailScreen({super.key, required this.doctor});

  final Doctor doctor;

  Future<void> _openLocation() async {
    debugPrint('DoctorDetailScreen._openLocation: opening location for doctorId=${doctor.id}');
    Uri? uri;
    if (doctor.googleMapsLink != null && doctor.googleMapsLink!.isNotEmpty) {
      uri = Uri.tryParse(doctor.googleMapsLink!);
    } else if (doctor.latitude != null && doctor.longitude != null) {
      uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${doctor.latitude},${doctor.longitude}');
    }
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(doctor.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit',
            onPressed: () => context.push('/doctors/edit', extra: doctor),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (doctor.doctorPhotoUrls.isNotEmpty) ...[
            Text('Doctor Photos', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: doctor.doctorPhotoUrls
                  .map((url) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: CachedNetworkImage(imageUrl: url, height: 120, fit: BoxFit.cover),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
          if (doctor.hospitalPhotoUrls.isNotEmpty) ...[
            Text('Hospital Photos', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: doctor.hospitalPhotoUrls
                  .map((url) => Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: CachedNetworkImage(imageUrl: url, height: 120, fit: BoxFit.cover),
                        ),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),
          ],
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.medical_services_outlined),
            title: Text(doctor.specialisation.isEmpty ? 'Specialisation not set' : doctor.specialisation),
            subtitle: const Text('Specialisation'),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.local_hospital_outlined),
            title: Text(doctor.hospitalName),
            subtitle: const Text('Hospital'),
          ),
          if (doctor.hasLocation)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.location_on_outlined),
              title: Text(doctor.locationAddress?.isNotEmpty == true
                  ? doctor.locationAddress!
                  : (doctor.googleMapsLink ?? 'GPS location captured')),
              subtitle: const Text('Location'),
              trailing: const Icon(Icons.open_in_new, size: 18),
              onTap: _openLocation,
            ),
          if (isAdmin && doctor.assignedMrName != null)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(doctor.assignedMrName!),
              subtitle: const Text('Assigned MR'),
            ),
          if (doctor.dateOfBirth != null && doctor.dateOfBirth!.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text('🎂', style: Theme.of(context).textTheme.titleMedium),
              title: Text(formatIsoForDisplay(doctor.dateOfBirth)),
              subtitle: const Text('Birthday'),
            ),
          if (doctor.marriageAnniversary != null && doctor.marriageAnniversary!.isNotEmpty)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Text('💍', style: Theme.of(context).textTheme.titleMedium),
              title: Text(formatIsoForDisplay(doctor.marriageAnniversary)),
              subtitle: const Text('Marriage Anniversary'),
            ),
          if (!isAdmin) ...[
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => showVisitLogDialog(context, ref, doctor),
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Log a Visit'),
            ),
          ],
        ],
      ),
    );
  }
}
