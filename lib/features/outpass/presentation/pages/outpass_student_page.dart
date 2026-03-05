// lib/features/outpass/presentation/pages/outpass_student_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../core/utils/validators.dart';
import '../providers/outpass_provider.dart';

class OutpassStudentPage extends ConsumerStatefulWidget {
  const OutpassStudentPage({super.key});

  @override
  ConsumerState<OutpassStudentPage> createState() => _OutpassStudentPageState();
}

class _OutpassStudentPageState extends ConsumerState<OutpassStudentPage> {
  void _showRequestDialog() {
    final ctrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Request Outpass'),
        content: Form(
          key: formKey,
          child: AppTextField(
            controller: ctrl,
            label: 'Reason',
            hint: 'Reason for leaving…',
            maxLines: 3,
            validator: (v) => Validators.required(v, field: 'Reason'),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(context);
              await ref.read(outpassProvider.notifier).requestOutpass(ctrl.text.trim());
              if (mounted) AppSnackbar.success(context, 'Outpass requested');
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final outpassAsync = ref.watch(outpassProvider);
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(title: const Text('My Outpass')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showRequestDialog,
        backgroundColor: AppTheme.studentPrimary,
        icon: const Icon(Icons.add),
        label: const Text('Request Outpass'),
      ),
      body: outpassAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppTheme.error))),
        data: (outpasses) {
          if (outpasses.isEmpty) {
            return const EmptyStateWidget(icon: Icons.exit_to_app_outlined, title: 'No outpass requests', subtitle: 'Request outpass when you need to go out');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: outpasses.length,
            itemBuilder: (_, i) => _OutpassCard(outpass: outpasses[i]),
          );
        },
      ),
    );
  }
}

class _OutpassCard extends ConsumerWidget {
  final Map<String, dynamic> outpass;
  const _OutpassCard({required this.outpass});

  Color _color(String status) {
    switch (status) {
      case 'Pending': return AppTheme.statusPending;
      case 'Approved': return AppTheme.statusResolved;
      default: return AppTheme.statusRejected;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = outpass['status'] as String;
    final isApproved = status == 'Approved';
    final hasOutTime = outpass['out_time'] != null;
    final hasInTime = outpass['in_time'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _color(status).withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Text(outpass['reason'] ?? '', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary), maxLines: 2, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: _color(status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
            child: Text(status, style: TextStyle(fontSize: 11, color: _color(status), fontWeight: FontWeight.w600)),
          ),
        ]),
        const SizedBox(height: 6),
        Text(DateFormatter.formatWithTime(DateTime.parse(outpass['created_at'])), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
        if (isApproved && !hasOutTime) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => ref.read(outpassProvider.notifier).markOut(outpass['id']),
              icon: const Icon(Icons.arrow_upward, size: 16),
              label: const Text('Mark OUT'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.success, minimumSize: const Size(0, 36)),
            ),
          ),
        ],
        if (hasOutTime && !hasInTime) ...[
          const SizedBox(height: 6),
          Text('Out: ${DateFormatter.formatWithTime(DateTime.parse(outpass['out_time']))}', style: const TextStyle(fontSize: 12, color: AppTheme.warning)),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => ref.read(outpassProvider.notifier).markIn(outpass['id']),
              icon: const Icon(Icons.arrow_downward, size: 16),
              label: const Text('Mark IN'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.info, minimumSize: const Size(0, 36)),
            ),
          ),
        ],
        if (hasInTime)
          Text('Returned: ${DateFormatter.formatWithTime(DateTime.parse(outpass['in_time']))}', style: const TextStyle(fontSize: 12, color: AppTheme.success)),
      ]),
    );
  }
}
