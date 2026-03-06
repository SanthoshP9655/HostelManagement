// lib/features/warden_management/presentation/pages/warden_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../hostel_management/presentation/providers/hostel_provider.dart';
import '../providers/warden_provider.dart';

class WardenListPage extends ConsumerWidget {
  const WardenListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wardensAsync = ref.watch(wardenListProvider);
    final hostelsAsync = ref.watch(hostelListProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Manage Wardens'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(wardenListProvider),
          ),
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: () => context.push(AppRoutes.adminWardenForm),
          ),
        ],
      ),
      body: wardensAsync.when(
        data: (wardens) => Column(
          children: [
            // Search and Filters
            Padding(
              padding: const EdgeInsets.all(16),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        style: const TextStyle(color: AppTheme.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search wardens...',
                          hintStyle: const TextStyle(color: AppTheme.textSecondary),
                          prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                          filled: true,
                          fillColor: AppTheme.bgCard,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: (val) =>
                            ref.read(wardenListProvider.notifier).setSearch(val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 1,
                      child: hostelsAsync.when(
                        data: (hostels) => DropdownButtonFormField<String>(
                          value: null,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: AppTheme.bgCard,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                          dropdownColor: AppTheme.bgCard,
                          hint: const Text('All Hostels', style: TextStyle(color: AppTheme.textSecondary, fontSize: 14)),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All Hostels', style: TextStyle(color: AppTheme.textPrimary, fontSize: 14))),
                            ...hostels.map((h) => DropdownMenuItem(
                                  value: h['id'] as String,
                                  child: Text(h['name'] as String, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 14)),
                                ))
                          ],
                          onChanged: (val) =>
                              ref.read(wardenListProvider.notifier).setHostelFilter(val),
                        ),
                        loading: () => const Center(child: CircularProgressIndicator()),
                        error: (_, __) => const SizedBox(),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // List
            Expanded(
              child: wardens.isEmpty
                  ? EmptyStateWidget(
                      icon: Icons.person_off,
                      title: 'No Wardens Found',
                      subtitle: 'Try adjusting filters or add a new warden',
                      buttonLabel: 'Add Warden',
                      onButtonTap: () => context.push(AppRoutes.adminWardenForm),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: wardens.length,
                      itemBuilder: (context, index) {
                        final w = wardens[index];
                        final hostelName = w['hostels']?['name'] ?? 'Unassigned';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          color: AppTheme.bgCard,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: ExpansionTile(
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.adminPrimary.withValues(alpha: 0.2), // Used withValues instead of withOpacity
                              child: Text(
                                (w['name'] as String)[0].toUpperCase(),
                                style: const TextStyle(color: AppTheme.adminPrimary, fontWeight: FontWeight.bold),
                              ),
                            ),
                            title: Text(
                              w['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                            ),
                            subtitle: Text(
                              'Code: ${w['warden_code']} | $hostelName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: AppTheme.textSecondary),
                            ),
                            iconColor: AppTheme.textPrimary,
                            collapsedIconColor: AppTheme.textSecondary,
                            childrenPadding: const EdgeInsets.all(16).copyWith(top: 0),
                            children: [
                              const Divider(color: AppTheme.divider),
                              const SizedBox(height: 8),
                              _DetailRow(icon: Icons.phone, title: 'Contact', value: w['contact_number'] as String? ?? 'N/A'),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.edit, size: 18, color: AppTheme.info),
                                    label: const Text('Edit', style: TextStyle(color: AppTheme.info)),
                                    onPressed: () => context.push(AppRoutes.adminWardenForm, extra: w),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton.icon(
                                    icon: const Icon(Icons.delete, size: 18, color: AppTheme.error),
                                    label: const Text('Delete', style: TextStyle(color: AppTheme.error)),
                                    onPressed: () => _confirmDelete(context, ref, w['id']),
                                  ),
                                ],
                              )
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
        loading: () => const LoadingWidget(),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: AppTheme.error))),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Delete Warden?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: AppTheme.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary))),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: AppTheme.error))),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(wardenListProvider.notifier).deleteWarden(id);
        if (context.mounted) AppSnackbar.success(context, 'Warden deleted successfully');
      } catch (e) {
        if (context.mounted) AppSnackbar.error(context, 'Error deleting warden: $e');
      }
    }
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  const _DetailRow({required this.icon, required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.textSecondary),
        const SizedBox(width: 8),
        Text('$title: ', style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
        Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
