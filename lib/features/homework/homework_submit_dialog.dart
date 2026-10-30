import 'package:flutter/material.dart';

import '../../data/models/homework/homework_model.dart';
import '../../services/file_picker/file_picker_service.dart';
import '../../shared/theme/spacing.dart';
import '../../shared/widgets/error_text.dart';
import 'homework_controller.dart';

/// 打开「交作业」弹窗，返回是否真的交上去了。
///
/// 旧项目是一个独立的 `UploadHomeDialog`：先挑文件、列表里能删、备注可留空、
/// 没选文件不给按提交。Flutter 之前把这一整套省掉了 —— 详情弹窗底部一个按钮
/// 直接调仓库，仓库里再弹系统文件选择器，用户既看不到「选了哪些」，也说不清
/// 「提交到底在哪」。这里把那套交互补回来。
Future<bool> showHomeworkSubmitDialog(
  BuildContext context, {
  required Homework homework,
  required HomeworkController controller,
  Future<List<PickedFileInfo>> Function()? pickFiles,
}) async {
  final submitted = await showDialog<bool>(
    context: context,
    builder: (_) => HomeworkSubmitDialog(
      homework: homework,
      controller: controller,
      pickFiles: pickFiles,
    ),
  );
  return submitted ?? false;
}

class HomeworkSubmitDialog extends StatefulWidget {
  const HomeworkSubmitDialog({
    super.key,
    required this.homework,
    required this.controller,
    this.pickFiles,
  });

  final Homework homework;
  final HomeworkController controller;

  /// 选文件。测试里注入假实现；正常运行时由页面从 `ServiceScope` 取。
  final Future<List<PickedFileInfo>> Function()? pickFiles;

  @override
  State<HomeworkSubmitDialog> createState() => _HomeworkSubmitDialogState();
}

class _HomeworkSubmitDialogState extends State<HomeworkSubmitDialog> {
  /// 桌面端弹窗别拉太宽：一行几百字读不下去。
  static const double _maxWidth = 520;

  final List<PickedFileInfo> _files = [];
  final TextEditingController _content = TextEditingController();

  bool _picking = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _content.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final pick = widget.pickFiles;
    if (pick == null || _picking) return;
    setState(() {
      _picking = true;
      _error = null;
    });
    try {
      final picked = await pick();
      if (!mounted) return;
      setState(() {
        _picking = false;
        for (final file in picked) {
          // 同一个文件选两次不重复加：平台按路径去重，界面上也别出现两行。
          if (file.path.isEmpty) continue;
          if (_files.any((item) => item.path == file.path)) continue;
          _files.add(file);
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _picking = false;
        _error = errorText(error);
      });
    }
  }

  void _remove(PickedFileInfo file) {
    setState(() => _files.remove(file));
  }

  Future<void> _submit() async {
    if (_files.isEmpty || _submitting) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.controller.upload(
        widget.homework,
        filePaths: _files.map((file) => file.path).toList(growable: false),
        content: _content.text.trim(),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _submitting = false;
        _error = errorText(error);
      });
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final media = MediaQuery.sizeOf(context);
    return Dialog(
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.xxl,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: _maxWidth,
          maxHeight: media.height * 0.82,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.sm,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('提交作业', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    widget.homework.title.isEmpty
                        ? widget.homework.courseName
                        : '${widget.homework.courseName} · ${widget.homework.title}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: scheme.outlineVariant),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.lg,
                  AppSpacing.xl,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '附件',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          _files.isEmpty ? '必填' : '${_files.length} 个',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        const Spacer(),
                        OutlinedButton.icon(
                          onPressed: _picking || _submitting ? null : _pick,
                          icon: _picking
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.attach_file, size: 18),
                          label: Text(_picking ? '选择中…' : '添加文件'),
                        ),
                      ],
                    ),
                    if (_files.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.xs),
                        child: Text(
                          '先添加要交的文件，平台不接受空附件提交',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      )
                    else
                      for (final file in _files)
                        _PickedFileTile(
                          file: file,
                          onRemove: _submitting ? null : () => _remove(file),
                        ),
                    const SizedBox(height: AppSpacing.lg),
                    TextField(
                      controller: _content,
                      enabled: !_submitting,
                      minLines: 2,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        labelText: '备注（可留空）',
                        hintText: '给老师留一句话',
                        alignLabelWithHint: true,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline,
                            size: 16,
                            color: scheme.error,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              _error!,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: scheme.error),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    // 没选文件就是不能交：平台那两步流程的第一步入参都没有。
                    onPressed: _files.isEmpty || _submitting ? null : _submit,
                    icon: _submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.upload_file, size: 18),
                    label: Text(_submitting ? '提交中…' : '提交'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 已选文件的一行：名字 + 体积 + 移除。
class _PickedFileTile extends StatelessWidget {
  const _PickedFileTile({required this.file, required this.onRemove});

  final PickedFileInfo file;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = _formatSize(file.sizeBytes);
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        children: [
          Icon(Icons.description_outlined, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              file.name.isEmpty ? file.path : file.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (size.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.sm),
            Text(
              size,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          IconButton(
            tooltip: '移除',
            onPressed: onRemove,
            iconSize: 18,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.close, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

String _formatSize(int bytes) {
  if (bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
