// lib/features/hostel_management/presentation/pages/hostel_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../providers/hostel_provider.dart';

class HostelListPage extends ConsumerWidget {
  const HostelListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hostelsAsync = ref.watch(hostelListProvider);
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Hostels'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push(AppRoutes.adminHostelForm),
          ),
        ],
      ),
      body: hostelsAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppTheme.error))),
        data: (hostels) {
          if (hostels.isEmpty) {
            return EmptyStateWidget(
              icon: Icons.apartment_outlined,
              title: 'No hostels yet',
              subtitle: 'Add your first hostel to get started',
              buttonLabel: 'Add Hostel',
              onButtonTap: () => context.push(AppRoutes.adminHostelForm),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: hostels.length,
            itemBuilder: (_, i) {
              final h = hostels[i];
              final wardens = h['wardens'] as List? ?? [];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.adminPrimary.withOpacity(0.2), width: 1),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: AppTheme.adminPrimary.withOpacity(0.1), shape: BoxShape.circle),
                      child: const Icon(Icons.apartment, color: AppTheme.adminPrimary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(h['name'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      Text('Block: ${h['block']}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ])),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      onPressed: () => context.push(AppRoutes.adminHostelForm, extra: h),
                      color: AppTheme.textSecondary,
                    ),
                  ]),
                  if (wardens.isNotEmpty) ...[
                    const Divider(height: 16),
                    Row(children: [
                      const Icon(Icons.person_pin, size: 14, color: AppTheme.wardenPrimary),
                      const SizedBox(width: 6),
                      Text('Warden: ${wardens.first['name']} (${wardens.first['warden_code']})',
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ]),
                  ],
                ]),
              );
            },
          );
        },
      ),
    );
  }
}
