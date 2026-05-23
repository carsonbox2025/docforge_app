import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../shared/widgets/common_widgets.dart';
import '../../data/models/glossary_models.dart';
import '../../domain/providers/glossary_provider.dart';

class GlossaryPage extends ConsumerWidget {
  const GlossaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(glossaryProvider);

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Column(
        children: [
          _buildAppBar(context, ref),
          _buildLanguagePairFilter(ref, state),
          Expanded(
            child: state.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : state.filteredEntries.isEmpty
                    ? const EmptyState(
                        title: '暂无术语',
                        subtitle: '点击右上角添加术语',
                        icon: Icons.book_outlined,
                      )
                    : _buildGlossaryList(ref, state),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, WidgetRef ref) {
    return Container(
      color: AppColors.surface,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpacing.md, AppSpacing.sm, AppSpacing.lg, AppSpacing.sm),
          child: Row(
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, size: 20, color: AppColors.text),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              ),
              const Text(
                '术语表管理',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () => _showAddDialog(context, ref),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBg,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: AppColors.primary),
                      SizedBox(width: 3),
                      Text(
                        '添加',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguagePairFilter(WidgetRef ref, GlossaryState state) {
    final pairs = ['全部', ...LanguagePair.defaults.map((p) => p.label)];
    return Container(
      color: AppColors.surface,
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 0, AppSpacing.lg, AppSpacing.md),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: pairs.map((pair) {
            final isSelected = (state.selectedLanguagePair ?? '全部') == pair;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => ref.read(glossaryProvider.notifier).setLanguagePair(pair == '全部' ? null : pair, clearSelection: pair == '全部'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: 1.5,
                    ),
                  ),
                  constraints: const BoxConstraints(minHeight: 34),
                  child: Center(
                    child: Text(
                      pair,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isSelected ? Colors.white : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildGlossaryList(WidgetRef ref, GlossaryState state) {
    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      itemCount: state.filteredEntries.length,
      itemBuilder: (context, index) {
        final entry = state.filteredEntries[index];
        return _GlossaryCard(
          entry: entry,
          onEdit: () => _showEditDialog(context, ref, entry),
          onDelete: () => ref.read(glossaryProvider.notifier).deleteEntry(entry.id),
        );
      },
    );
  }

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final sourceController = TextEditingController();
    final targetController = TextEditingController();
    final noteController = TextEditingController();
    String selectedPair = LanguagePair.defaults.first.label;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('添加术语', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Language pair selector
              StatefulBuilder(
                builder: (ctx, setModalState) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('语言对', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: selectedPair,
                            isExpanded: true,
                            items: LanguagePair.defaults.map((p) => DropdownMenuItem(
                              value: p.label,
                              child: Text(p.label, style: const TextStyle(fontSize: 13)),
                            )).toList(),
                            onChanged: (v) => setModalState(() => selectedPair = v!),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 14),
              // Source term
              const Text('源语言术语', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              TextField(
                controller: sourceController,
                decoration: InputDecoration(
                  hintText: '输入源语言术语',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Target term
              const Text('目标语言术语', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              TextField(
                controller: targetController,
                decoration: InputDecoration(
                  hintText: '输入目标语言术语',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Note
              const Text('备注（可选）', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  hintText: '添加备注',
                  hintStyle: const TextStyle(fontSize: 13, color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    if (sourceController.text.trim().isEmpty || targetController.text.trim().isEmpty) return;
                    ref.read(glossaryProvider.notifier).addEntry(GlossaryEntry(
                      id: DateTime.now().millisecondsSinceEpoch,
                      sourceTerm: sourceController.text.trim(),
                      targetTerm: targetController.text.trim(),
                      languagePairLabel: selectedPair,
                      note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                    ));
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    elevation: 0,
                  ),
                  child: const Text('添加术语', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref, GlossaryEntry entry) {
    final sourceController = TextEditingController(text: entry.sourceTerm);
    final targetController = TextEditingController(text: entry.targetTerm);
    final noteController = TextEditingController(text: entry.note ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
            MediaQuery.of(ctx).viewInsets.bottom + AppSpacing.lg,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('编辑术语', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: const Icon(Icons.close, size: 20, color: AppColors.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primaryBg,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.translate, size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      entry.languagePairLabel,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Text('源语言术语', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              TextField(
                controller: sourceController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('目标语言术语', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              TextField(
                controller: targetController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text('备注（可选）', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
              const SizedBox(height: 8),
              TextField(
                controller: noteController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bg,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton(
                  onPressed: () {
                    ref.read(glossaryProvider.notifier).updateEntry(entry.copyWith(
                      sourceTerm: sourceController.text.trim(),
                      targetTerm: targetController.text.trim(),
                      note: noteController.text.trim().isEmpty ? null : noteController.text.trim(),
                    ));
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                    elevation: 0,
                  ),
                  child: const Text('保存修改', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GlossaryCard extends StatelessWidget {
  final GlossaryEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GlossaryCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: 4),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Arrow icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryBg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.translate, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          // Terms
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.sourceTerm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.text),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Icon(Icons.arrow_forward, size: 14, color: AppColors.textMuted),
                    ),
                    Flexible(
                      child: Text(
                        entry.targetTerm,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      entry.languagePairLabel,
                      style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                    ),
                    if (entry.note != null && entry.note!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHover,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          entry.note!,
                          style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Actions
          PopupMenuButton<String>(
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.more_vert, size: 18, color: AppColors.textMuted),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'edit', child: Text('编辑', style: TextStyle(fontSize: 13))),
              const PopupMenuItem(value: 'delete', child: Text('删除', style: TextStyle(fontSize: 13, color: AppColors.error))),
            ],
          ),
        ],
      ),
    );
  }
}
