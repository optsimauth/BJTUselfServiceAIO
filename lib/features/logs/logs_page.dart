import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import '../../app/app_router.dart';
import '../../core/utils/log_recorder.dart';
import '../../shared/theme/spacing.dart';
import '../../shared/widgets/dialog/app_dialog.dart';

/// 日志页（隐藏入口：/logs）。
///
/// 日志是自动落盘的，这里只做三件事：看保存位置、看某一份日志的内容、全部清空。
/// 原来那个「导出全部日志」已经删掉 —— 它只是把同一批文件复制到另一个目录，
/// 而「保存位置」那一条（设置里可改）已经把这件事覆盖了，两个入口是重复的。
class LogsPage extends StatefulWidget {
  const LogsPage({super.key});

  @override
  State<LogsPage> createState() => _LogsPageState();
}

class _LogsPageState extends State<LogsPage> {


  List<File> _files = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final files = await LogRecorder.instance.listFiles();
    if (!mounted) return;
    setState(() {
      _files = files;
      _loading = false;
    });
  }

  /// 点开一份日志：底部弹层里直接看内容。
  ///
  /// 日志可能几百 KB，全量塞进 Text 会卡，所以只取尾部 [_LogViewerState._previewBytes]，
  /// 并在正文开头说明「仅显示最后 N KB」，所以超长日志也滚得动。
  Future<void> _openLog(File file) async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => _LogViewer(file: file),
    );
  }


  Future<void> _clear() async {
    final confirmed = await AppDialog.confirm(
      context,
      title: '清空日志',
      message: '会删掉当前目录下的全部日志文件，不能恢复。',
      confirmText: '清空',
      destructive: true,
    );
    if (!confirmed) return;
    await LogRecorder.instance.clear();
    await _refresh();
    if (mounted) _toast('已清空');
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final directory = LogRecorder.instance.directory;
    return Scaffold(
      appBar: AppBar(title: const Text('日志')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('保存位置'),
            subtitle: Text(directory?.path ?? '不可用', maxLines: 2),
            trailing: const Icon(Icons.folder_open, size: 20),
            onTap: () => context.push(AppRoutes.settings),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('清空日志'),
            enabled: _files.isNotEmpty,
            onTap: _clear,
          ),
          const Divider(),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_files.isEmpty)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Text(
                '还没有日志。App 出错时会自动记到这里，一般不用管它。',
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final file in _files)
              _FileTile(file: file, onTap: () => _openLog(file)),
        ],
      ),
    );
  }
}

class _FileTile extends StatelessWidget {
  const _FileTile({required this.file, required this.onTap});

  final File file;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      title: Text(p.basename(file.path)),
      subtitle: Text('${_size(file)} · ${_modified(file)} · 点开看内容'),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  String _size(File file) {
    final bytes = file.lengthSync();
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }

  String _modified(File file) {
    final time = file.lastModifiedSync();
    return '${time.year}-${_two(time.month)}-${_two(time.day)} '
        '${_two(time.hour)}:${_two(time.minute)}';
  }

  String _two(int value) => value.toString().padLeft(2, '0');
}

/// 日志查看弹层：标题 + 可选中正文（等宽字体，可长按复制）。
class _LogViewer extends StatefulWidget {
  const _LogViewer({required this.file});

  final File file;

  @override
  State<_LogViewer> createState() => _LogViewerState();
}

class _LogViewerState extends State<_LogViewer> {
  /// 单次最多读这么多字节，超出只给尾部（最新的错更值得看）。
  static const int _previewBytes = 256 * 1024;

  late final Future<String> _content = _read();

  Future<String> _read() async {
    try {
      final bytes = await widget.file.readAsBytes();
      final truncated = bytes.length > _previewBytes;
      final body = truncated
          ? bytes.sublist(bytes.length - _previewBytes)
          : bytes;
      final text = const Utf8Decoder(allowMalformed: true).convert(body);
      return truncated
          ? '（仅显示最后 ${body.length ~/ 1024} KB）\n\n$text'
          : text;
    } catch (error) {
      return '读不出来：$error';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      p.basename(widget.file.path),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),

                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<String>(
                future: _content,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: SelectableText(
                      snapshot.data ?? '',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        height: 1.4,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

}