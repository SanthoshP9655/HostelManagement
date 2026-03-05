// lib/features/notices/presentation/pages/notices_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../providers/notice_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class NoticesPage extends ConsumerWidget {
  final String role;
  const NoticesPage({super.key, required this.role});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noticesAsync = ref.watch(noticeListProvider);
    final session = ref.watch(sessionProvider).valueOrNull;
    final canCreate = session?.role != AppConstants.roleStudent;
    final formRoute = role == 'admin' ? AppRoutes.adminNoticeForm : AppRoutes.wardenNoticeForm;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Notice Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(noticeListProvider),
          ),
        ],
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push(formRoute),
              backgroundColor: AppTheme.info,
              icon: const Icon(Icons.add),
              label: const Text('New Notice'),
            )
          : null,
      body: noticesAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppTheme.error))),
        data: (notices) {
          if (notices.isEmpty) {
            return const EmptyStateWidget(icon: Icons.campaign_outlined, title: 'No notices yet', subtitle: 'Notices from admin and warden will appear here');
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: notices.length,
            itemBuilder: (_, i) {
              final n = notices[i];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.info.withOpacity(0.2), width: 1),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.campaign, size: 18, color: AppTheme.info),
                    const SizedBox(width: 8),
                    Expanded(child: Text(n['title'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary))),
                    if (canCreate) ...[
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () => context.push(formRoute, extra: n),
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 16),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: () async {
                          await ref.read(noticeListProvider.notifier).deleteNotice(n['id']);
                          if (context.mounted) AppSnackbar.success(context, 'Notice deleted');
                        },
                        color: AppTheme.error,
                      ),
                    ],
                  ]),
                  const SizedBox(height: 8),
                  Text(n['description'], style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
                  const SizedBox(height: 8),
                  Text(DateFormatter.timeAgo(DateTime.parse(n['created_at'])), style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
