// lib/features/complaints/presentation/pages/complaints_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../providers/complaint_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ComplaintsPage extends ConsumerStatefulWidget {
  final String role;
  const ComplaintsPage({super.key, required this.role});

  @override
  ConsumerState<ComplaintsPage> createState() => _ComplaintsPageState();
}

class _ComplaintsPageState extends ConsumerState<ComplaintsPage> {
  @override
  Widget build(BuildContext context) {
    final complaintsAsync = ref.watch(complaintListProvider);
    final session = ref.watch(sessionProvider).valueOrNull;
    final isStudent = session?.role == AppConstants.roleStudent;
    final formRoute = isStudent ? AppRoutes.studentComplaintForm : null;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Complaints'),
        actions: [
          _FilterButton(role: widget.role),
        ],
      ),
      floatingActionButton: isStudent
          ? FloatingActionButton.extended(
              onPressed: () => context.push(formRoute!),
              backgroundColor: AppTheme.studentPrimary,
              icon: const Icon(Icons.add),
              label: const Text('New Complaint'),
            )
          : null,
      body: complaintsAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.error))),
        data: (complaints) {
          if (complaints.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.report_outlined,
              title: 'No complaints found',
              subtitle: isStudent ? 'Submit a complaint if you have any issues' : null,
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: complaints.length,
            itemBuilder: (_, i) => _ComplaintCard(
              complaint: complaints[i],
              role: widget.role,
            ),
          );
        },
      ),
    );
  }
}

class _FilterButton extends ConsumerStatefulWidget {
  final String role;
  const _FilterButton({required this.role});

  @override
  ConsumerState<_FilterButton> createState() => _FilterButtonState();
}

class _FilterButtonState extends ConsumerState<_FilterButton> {
  String? _status;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String?>(
      icon: const Icon(Icons.filter_list),
      onSelected: (v) {
        setState(() => _status = v);
        ref.read(complaintListProvider.notifier).setFilter(status: v);
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: null, child: Text('All')),
        const PopupMenuItem(value: 'Pending', child: Text('Pending')),
        const PopupMenuItem(value: 'In Progress', child: Text('In Progress')),
        const PopupMenuItem(value: 'Resolved', child: Text('Resolved')),
        const PopupMenuItem(value: 'Rejected', child: Text('Rejected')),
      ],
    );
  }
}

class _ComplaintCard extends ConsumerWidget {
  final Map<String, dynamic> complaint;
  final String role;
  const _ComplaintCard({required this.complaint, required this.role});

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending': return AppTheme.statusPending;
      case 'In Progress': return AppTheme.statusInProgress;
      case 'Resolved': return AppTheme.statusResolved;
      default: return AppTheme.statusRejected;
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'Low': return AppTheme.priorityLow;
      case 'Medium': return AppTheme.priorityMedium;
      case 'High': return AppTheme.priorityHigh;
      default: return AppTheme.priorityEmergency;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = complaint['status'] as String;
    final priority = complaint['priority'] as String;
    final detailRoute = role == 'admin'
        ? AppRoutes.adminComplaintDetail
        : role == 'warden'
            ? AppRoutes.wardenComplaintDetail
            : AppRoutes.studentComplaintDetail;

    return GestureDetector(
      onTap: () => context.push(detailRoute, extra: complaint['id']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _statusColor(status).withOpacity(0.3), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    complaint['title'],
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _statusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(status, style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(complaint['description'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
            const SizedBox(height: 8),
            Row(children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: _priorityColor(priority).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(priority, style: TextStyle(fontSize: 10, color: _priorityColor(priority), fontWeight: FontWeight.w600)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(4)),
                child: Text(complaint['category'] ?? '', style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary)),
              ),
              const Spacer(),
              Text(
                DateFormatter.timeAgo(DateTime.parse(complaint['created_at'])),
                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}
