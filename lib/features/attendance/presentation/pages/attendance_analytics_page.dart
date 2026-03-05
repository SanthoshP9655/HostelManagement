// lib/features/attendance/presentation/pages/attendance_analytics_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class AttendanceAnalyticsPage extends ConsumerStatefulWidget {
  const AttendanceAnalyticsPage({super.key});

  @override
  ConsumerState<AttendanceAnalyticsPage> createState() => _AttendanceAnalyticsPageState();
}

class _AttendanceAnalyticsPageState extends ConsumerState<AttendanceAnalyticsPage> {
  List<Map<String, dynamic>> _data = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final session = ref.read(sessionProvider).valueOrNull;
    if (session == null) return;
    final today = DateFormatter.formatDate(DateTime.now());
    final hostels = await SupabaseService.instance.hostels
        .select('id,name')
        .eq('college_id', session.collegeId) as List;

    final results = await Future.wait(hostels.map((h) async {
      final records = await SupabaseService.instance.attendance
          .select('status')
          .eq('hostel_id', h['id'] as String)
          .eq('date', today) as List;
      final present = records.where((r) => r['status'] == 'Present').length;
      return {'hostel': h['name'], 'present': present, 'total': records.length, 'absent': records.length - present};
    }));

    setState(() { _data = results; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(title: const Text('Attendance Analytics')),
      body: _loading
          ? const LoadingWidget()
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Today — ${DateFormatter.format(DateTime.now())}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 16),
                  ..._data.map((d) => Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: AppTheme.bgCard, borderRadius: BorderRadius.circular(16)),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(d['hostel'], style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(height: 12),
                      Row(children: [
                        _Bar(label: 'Present', value: d['present'], total: d['total'], color: AppTheme.success),
                        const SizedBox(width: 12),
                        _Bar(label: 'Absent', value: d['absent'], total: d['total'], color: AppTheme.error),
                      ]),
                      const SizedBox(height: 8),
                      LinearProgressIndicator(
                        value: d['total'] == 0 ? 0 : d['present'] / d['total'],
                        backgroundColor: AppTheme.error.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation(AppTheme.success),
                        borderRadius: BorderRadius.circular(4),
                        minHeight: 8,
                      ),
                    ]),
                  )),
                ],
              ),
            ),
    );
  }
}

class _Bar extends StatelessWidget {
  final String label;
  final int value;
  final int total;
  final Color color;
  const _Bar({required this.label, required this.value, required this.total, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      Text('$value / $total', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
    ]));
  }
}
