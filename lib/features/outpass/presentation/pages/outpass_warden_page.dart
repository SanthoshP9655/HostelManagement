// lib/features/outpass/presentation/pages/outpass_warden_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../providers/outpass_provider.dart';

class OutpassWardenPage extends ConsumerStatefulWidget {
  const OutpassWardenPage({super.key});

  @override
  ConsumerState<OutpassWardenPage> createState() => _OutpassWardenPageState();
}

class _OutpassWardenPageState extends ConsumerState<OutpassWardenPage> {
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final outpassAsync = ref.watch(outpassProvider);
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Outpass Requests'),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(outpassProvider),
          ),
          PopupMenuButton<String?>(
            icon: const Icon(Icons.filter_list),
            onSelected: (v) {
              setState(() => _filter = v);
              ref.read(outpassProvider.notifier).setStatusFilter(v);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: null, child: Text('All')),
              const PopupMenuItem(value: 'Pending', child: Text('Pending')),
              const PopupMenuItem(value: 'Approved', child: Text('Approved')),
              const PopupMenuItem(value: 'Rejected', child: Text('Rejected')),
            ],
          ),
        ],
      ),
      body: outpassAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppTheme.error))),
        data: (outpasses) {
          if (outpasses.isEmpty) {
            return const EmptyStateWidget(icon: Icons.exit_to_app_outlined, title: 'No outpass requests', subtitle: 'Students\' outpass requests will appear here');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: outpasses.length,
            itemBuilder: (_, i) {
              final o = outpasses[i];
              final status = o['status'] as String;
              final student = o['students'] as Map<String, dynamic>?;
              final isPending = status == 'Pending';

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _statusColor(status).withOpacity(0.3), width: 1.5),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    CircleAvatar(
                      backgroundColor: AppTheme.wardenPrimary.withOpacity(0.15),
                      child: Text((student?['name'] ?? 'S')[0], style: const TextStyle(color: AppTheme.wardenPrimary, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(student?['name'] ?? 'Unknown', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      Text(student?['register_number'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
                      child: Text(status, style: TextStyle(fontSize: 11, color: _statusColor(status), fontWeight: FontWeight.w600)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  Text(o['reason'] ?? '', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  const SizedBox(height: 6),
                  Text(DateFormatter.formatWithTime(DateTime.parse(o['created_at'])), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                  if (isPending) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await ref.read(outpassProvider.notifier).approveOutpass(o['id'], o['student_id']);
                            if (context.mounted) AppSnackbar.success(context, 'Outpass approved');
                          },
                          icon: const Icon(Icons.check, size: 16),
                          label: const Text('Approve'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, minimumSize: const Size(0, 36)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            await ref.read(outpassProvider.notifier).rejectOutpass(o['id'], o['student_id']);
                            if (context.mounted) AppSnackbar.success(context, 'Outpass rejected');
                          },
                          icon: const Icon(Icons.close, size: 16),
                          label: const Text('Reject'),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error, minimumSize: const Size(0, 36)),
                        ),
                      ),
                    ]),
                  ],
                  if (o['out_time'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('OUT: ${DateFormatter.formatWithTime(DateTime.parse(o['out_time']))}', style: const TextStyle(fontSize: 11, color: AppTheme.warning)),
                    ),
                  if (o['in_time'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: Text('IN: ${DateFormatter.formatWithTime(DateTime.parse(o['in_time']))}', style: const TextStyle(fontSize: 11, color: AppTheme.success)),
                    ),
                ]),
              );
            },
          );
        },
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending': return AppTheme.statusPending;
      case 'Approved': return AppTheme.statusResolved;
      default: return AppTheme.statusRejected;
    }
  }
}
