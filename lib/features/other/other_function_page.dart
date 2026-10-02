import 'package:flutter/material.dart';

import '../../app/service_locator.dart';
import '../../shared/widgets/buttons/app_buttons.dart';
import '../../shared/widgets/dialog/app_dialog.dart';
import '../../shared/widgets/login_required.dart';

/// 其他功能：校历、成绩单等一次性动作。
class OtherFunctionPage extends StatefulWidget {
  const OtherFunctionPage({super.key});

  @override
  State<OtherFunctionPage> createState() => _OtherFunctionPageState();
}

class _OtherFunctionPageState extends State<OtherFunctionPage> {
  late final _courseRepository = ServiceScope.of(context).courseRepository;
  late final _gradeRepository = ServiceScope.of(context).gradeRepository;

  bool _busy = false;

  Future<void> _run(
    Future<String> Function() action,
    String name,
  ) async {
    setState(() => _busy = true);
    try {
      final path = await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('$name 已保存到：$path')));
    } catch (error) {
      if (!mounted) return;
      await AppDialog.error(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: const Text('其他功能'),
      ),
      body: LoginRequired(
        builder: (context) => ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.calendar_month),
              title: const Text('下载校历'),
              onTap: _busy
                  ? null
                  : () =>
                        _run(_courseRepository.downloadSchoolCalendar, '校历'),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf),
              title: const Text('下载中文成绩单'),
              onTap: _busy
                  ? null
                  : () => _run(
                      () => _gradeRepository.downloadReport(english: false),
                      '中文成绩单',
                    ),
            ),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('下载英文成绩单'),
              onTap: _busy
                  ? null
                  : () => _run(
                      () => _gradeRepository.downloadReport(english: true),
                      '英文成绩单',
                    ),
            ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
