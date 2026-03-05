// lib/features/attendance/presentation/pages/attendance_mark_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/utils/date_formatter.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../providers/attendance_provider.dart';

class AttendanceMarkPage extends ConsumerStatefulWidget {
  const AttendanceMarkPage({super.key});

  @override
  ConsumerState<AttendanceMarkPage> createState() => _AttendanceMarkPageState();
}

class _AttendanceMarkPageState extends ConsumerState<AttendanceMarkPage> {
  DateTime _date = DateTime.now();
  bool _saving = false;
  Map<String, String> _draft = {};

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() { _date = picked; _draft = {}; });
      ref.read(attendanceProvider.notifier).setDate(picked);
    }
  }

  Future<void> _saveAll(List<Map<String, dynamic>> students) async {
    setState(() => _saving = true);
    try {
      final records = students.map((s) => {
        'id': s['id'],
        'attendance_status': _draft[s['id']] ?? s['attendance_status'] ?? 'Present',
      }).toList();
      await ref.read(attendanceProvider.notifier).saveBulkAttendance(records);
      if (mounted) AppSnackbar.success(context, 'Attendance saved');
    } catch (e) {
      if (mounted) AppSnackbar.error(context, e.toString());
    }
    setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final attendanceAsync = ref.watch(attendanceProvider);
    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Mark Attendance'),
        actions: [
          TextButton.icon(
            onPressed: _pickDate,
            icon: const Icon(Icons.calendar_today, size: 18),
            label: Text(DateFormatter.format(_date), style: const TextStyle(fontSize: 13)),
          ),
        ],
      ),
      body: attendanceAsync.when(
        loading: () => const ShimmerList(),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: AppTheme.error))),
        data: (students) {
          if (students.isEmpty) return const Center(child: Text('No students in this hostel', style: TextStyle(color: AppTheme.textSecondary)));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Expanded(child: Text('${students.length} students', style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary))),
                  TextButton(onPressed: () => setState(() => _draft = {for (var s in students) s['id']: 'Present'}), child: const Text('All Present')),
                  const SizedBox(width: 8),
                  TextButton(onPressed: () => setState(() => _draft = {for (var s in students) s['id']: 'Absent'}), child: const Text('All Absent', style: TextStyle(color: AppTheme.error))),
                ]),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: students.length,
                  itemBuilder: (_, i) {
                    final s = students[i];
                    final status = _draft[s['id']] ?? s['attendance_status'] ?? 'Present';
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgCard,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(children: [
                        CircleAvatar(
                          backgroundColor: (status == 'Present' ? AppTheme.success : AppTheme.error).withOpacity(0.15),
                          child: Text((s['name'] as String)[0], style: TextStyle(color: status == 'Present' ? AppTheme.success : AppTheme.error, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(s['name'], style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          Text(s['register_number'] ?? '', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                        ])),
                        Row(children: [
                          _StatusButton(label: 'P', selected: status == 'Present', color: AppTheme.success, onTap: () => setState(() => _draft[s['id']] = 'Present')),
                          const SizedBox(width: 8),
                          _StatusButton(label: 'A', selected: status == 'Absent', color: AppTheme.error, onTap: () => setState(() => _draft[s['id']] = 'Absent')),
                        ]),
                      ]),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: AppButton(label: 'Save Attendance', isLoading: _saving, gradient: const [AppTheme.wardenPrimary, AppTheme.wardenSecondary], onPressed: () => _saveAll(students)),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatusButton extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _StatusButton({required this.label, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: selected ? color : AppTheme.bgSurface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: selected ? Colors.white : AppTheme.textSecondary))),
      ),
    );
  }
}
