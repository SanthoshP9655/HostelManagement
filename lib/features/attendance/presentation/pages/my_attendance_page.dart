// lib/features/attendance/presentation/pages/my_attendance_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../providers/attendance_provider.dart';

class MyAttendancePage extends ConsumerWidget {
  const MyAttendancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(myAttendanceProvider);

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(title: const Text('My Attendance')),
      body: attendanceAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppTheme.error))),
        data: (records) {
          if (records.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.how_to_reg_outlined,
              title: 'No attendance records yet',
              subtitle: 'Your warden has not marked attendance yet',
            );
          }
          final present = records.where((r) => r['status'] == 'Present').length;
          final pct = (present / records.length) * 100;

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: pct >= 75
                      ? [AppTheme.success, const Color(0xFF16A34A)]
                      : [AppTheme.error, const Color(0xFFB91C1C)]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Attendance %', style: TextStyle(color: Colors.white70, fontSize: 13)),
                      Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w800)),
                      Text('${records.length} days · $present present', style: const TextStyle(color: Colors.white60, fontSize: 12)),
                    ]),
                    const Spacer(),
                    CircularProgressIndicator(
                      value: pct / 100,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                      strokeWidth: 6,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: records.length,
                  itemBuilder: (_, i) {
                    final r = records[i];
                    final isPresent = r['status'] == 'Present';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        Icon(
                          isPresent ? Icons.check_circle : Icons.cancel_outlined,
                          color: isPresent ? AppTheme.success : AppTheme.error,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(r['date'] as String, style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                        const Spacer(),
                        Text(r['status'], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: isPresent ? AppTheme.success : AppTheme.error)),
                      ]),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
