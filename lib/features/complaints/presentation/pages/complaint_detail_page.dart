// lib/features/complaints/presentation/pages/complaint_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../providers/complaint_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class ComplaintDetailPage extends ConsumerStatefulWidget {
  final String complaintId;
  const ComplaintDetailPage({super.key, required this.complaintId});

  @override
  ConsumerState<ComplaintDetailPage> createState() => _ComplaintDetailPageState();
}

class _ComplaintDetailPageState extends ConsumerState<ComplaintDetailPage> {
  Map<String, dynamic>? _complaint;
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(complaintListProvider.notifier);
    final complaints = ref.read(complaintListProvider).valueOrNull ?? [];
    _complaint = complaints.firstWhere((c) => c['id'] == widget.complaintId, orElse: () => {});
    _history = await db.getHistory(widget.complaintId);
    setState(() => _loading = false);
  }

  Future<void> _changeStatus(String newStatus) async {
    final noteCtrl = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: Text('Change to $newStatus'),
        content: TextField(
          controller: noteCtrl,
          decoration: const InputDecoration(hintText: 'Add a note (optional)'),
          maxLines: 3,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, noteCtrl.text), child: const Text('Confirm')),
        ],
      ),
    );
    if (note == null) return;
    await ref.read(complaintListProvider.notifier).changeStatus(
          complaintId: widget.complaintId,
          newStatus: newStatus,
          oldStatus: _complaint?['status'] ?? 'Pending',
          note: note.isEmpty ? null : note,
        );
    if (mounted) {
      AppSnackbar.success(context, 'Status updated to $newStatus');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider).valueOrNull;
    final canChangeStatus = session?.role != AppConstants.roleStudent;

    if (_loading) return const Scaffold(body: LoadingWidget());
    if (_complaint == null || _complaint!.isEmpty) {
      return Scaffold(appBar: AppBar(title: const Text('Complaint')), body: const Center(child: Text('Not found')));
    }

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Complaint Detail'),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () { setState(() => _loading = true); _load(); },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(complaint: _complaint!),
            const SizedBox(height: 16),
            Text(_complaint!['description'] ?? '', style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5)),
            if (_complaint!['image_url'] != null && _complaint!['image_url'].toString().isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Attached Evidence', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => Dialog(
                      backgroundColor: Colors.transparent,
                      insetPadding: const EdgeInsets.all(10),
                      child: Stack(
                        alignment: Alignment.topRight,
                        children: [
                          InteractiveViewer(
                            panEnabled: true,
                            minScale: 0.5,
                            maxScale: 4.0,
                            child: Image.network(_complaint!['image_url']),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 30),
                            onPressed: () => Navigator.pop(ctx),
                          )
                        ],
                      ),
                    ),
                  );
                },
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: AppTheme.bgSurface,
                    border: Border.all(color: AppTheme.divider),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      _complaint!['image_url'],
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: CircularProgressIndicator(),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.broken_image, color: AppTheme.textSecondary, size: 40),
                                SizedBox(height: 8),
                                Text('Failed to load image', style: TextStyle(color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
            if (canChangeStatus) ...[
              const SizedBox(height: 24),
              const Text('Change Status', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: ['Pending', 'In Progress', 'Resolved', 'Rejected'].map((s) {
                  final isCurrent = _complaint?['status'] == s;
                  return ActionChip(
                    label: Text(s),
                    backgroundColor: isCurrent ? AppTheme.adminPrimary.withOpacity(0.2) : AppTheme.bgSurface,
                    labelStyle: TextStyle(color: isCurrent ? AppTheme.adminPrimary : AppTheme.textSecondary, fontSize: 12),
                    onPressed: isCurrent ? null : () => _changeStatus(s),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 24),
            const Text('History', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            const SizedBox(height: 12),
            ..._history.map((h) => _HistoryItem(item: h)),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Map<String, dynamic> complaint;
  const _Header({required this.complaint});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (complaint['students'] != null) ...[
            Row(
              children: [
                const Icon(Icons.person_outline, size: 14, color: AppTheme.adminPrimary),
                const SizedBox(width: 6),
                Text(
                  '${complaint['students']['name']} (${complaint['students']['register_number']})',
                  style: const TextStyle(fontSize: 12, color: AppTheme.adminPrimary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Text(complaint['title'] ?? '', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          Row(children: [
            _Badge(complaint['status'] ?? 'Pending'),
            const SizedBox(width: 8),
            _BadgeNeutral(complaint['category'] ?? ''),
            const SizedBox(width: 8),
            _BadgeNeutral(complaint['priority'] ?? ''),
          ]),
          const SizedBox(height: 8),
          Text(DateFormatter.format(DateTime.parse(complaint['created_at'])), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);
  Color get color {
    switch (text) {
      case 'Pending': return AppTheme.statusPending;
      case 'In Progress': return AppTheme.statusInProgress;
      case 'Resolved': return AppTheme.statusResolved;
      default: return AppTheme.statusRejected;
    }
  }
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
  );
}

class _BadgeNeutral extends StatelessWidget {
  final String text;
  const _BadgeNeutral(this.text);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(color: AppTheme.bgSurface, borderRadius: BorderRadius.circular(6)),
    child: Text(text, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
  );
}

class _HistoryItem extends StatelessWidget {
  final Map<String, dynamic> item;
  const _HistoryItem({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(children: [
          Container(
            width: 10,
            height: 10,
            decoration: const BoxDecoration(color: AppTheme.adminPrimary, shape: BoxShape.circle),
          ),
          Container(width: 1, height: 48, color: AppTheme.divider),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item['old_status'] ?? 'Created'} → ${item['new_status']}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                ),
                if (item['note'] != null) ...[
                  const SizedBox(height: 3),
                  Text(item['note'], style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
                const SizedBox(height: 3),
                Text(
                  '${item['changed_by_role']} · ${DateFormatter.formatWithTime(DateTime.parse(item['changed_at']))}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
