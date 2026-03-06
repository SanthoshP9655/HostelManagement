// lib/features/student_management/presentation/pages/student_list_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../providers/student_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class StudentListPage extends ConsumerStatefulWidget {
  final String role;
  const StudentListPage({super.key, required this.role});

  @override
  ConsumerState<StudentListPage> createState() => _StudentListPageState();
}

class _StudentListPageState extends ConsumerState<StudentListPage> {
  final _searchCtrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _searchCtrl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearch(String q) {
    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: AppConstants.debounceMs),
      () => ref.read(studentListProvider.notifier).setSearch(q),
    );
  }

  Future<void> _deleteStudent(String id, String name) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.bgCard,
        title: const Text('Delete Student'),
        content: Text('Remove $name? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref.read(studentListProvider.notifier).deleteStudent(id);
      if (mounted) AppSnackbar.success(context, '$name removed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentListProvider);
    final session = ref.watch(sessionProvider).valueOrNull;
    final canEdit = session?.role != AppConstants.roleStudent;
    final formRoute = widget.role == 'admin' ? AppRoutes.adminStudentForm : AppRoutes.wardenStudentForm;

    return Scaffold(
      backgroundColor: AppTheme.bgDark,
      appBar: AppBar(
        title: const Text('Students'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(studentListProvider),
          ),
          if (canEdit)
            IconButton(
              icon: const Icon(Icons.person_add_outlined),
              onPressed: () => context.push(formRoute),
            )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _onSearch,
              style: const TextStyle(color: AppTheme.textPrimary),
              decoration: InputDecoration(
                hintText: 'Search by name or register number…',
                prefixIcon: const Icon(Icons.search, size: 20, color: AppTheme.textSecondary),
                filled: true,
                fillColor: AppTheme.bgCard,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          ref.read(studentListProvider.notifier).setSearch('');
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: studentsAsync.when(
              loading: () => const ShimmerList(),
              error: (e, _) => Center(child: Text('Error: $e', style: const TextStyle(color: AppTheme.error))),
              data: (students) {
                if (students.isEmpty) {
                  return EmptyStateWidget(
                    icon: Icons.school_outlined,
                    title: 'No students found',
                    subtitle: 'Add your first student to get started',
                    buttonLabel: canEdit ? 'Add Student' : null,
                    onButtonTap: canEdit ? () => context.push(formRoute) : null,
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: students.length,
                  itemBuilder: (_, i) {
                    final s = students[i];
                    return _StudentCard(
                      student: s,
                      canEdit: canEdit,
                      onEdit: () => context.push(formRoute, extra: s),
                      onDelete: () => _deleteStudent(s['id'], s['name']),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _StudentCard({
    required this.student,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.divider, width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppTheme.adminPrimary.withOpacity(0.15),
            child: Text(
              (student['name'] as String)[0].toUpperCase(),
              style: const TextStyle(color: AppTheme.adminPrimary, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student['name'], style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(student['register_number'], style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                const SizedBox(height: 2),
                Text('Room ${student['room_number'] ?? '-'} | Year ${student['year'] ?? '-'}', style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
              ],
            ),
          ),
          if (canEdit) ...[
            IconButton(icon: const Icon(Icons.edit_outlined, size: 18), onPressed: onEdit, color: AppTheme.textSecondary),
            IconButton(icon: const Icon(Icons.delete_outline, size: 18), onPressed: onDelete, color: AppTheme.error),
          ],
        ],
      ),
    );
  }
}
