import 'package:file_picker/file_picker.dart';

class PickedFileInfo {
  const PickedFileInfo({
    required this.name,
    required this.path,
    this.sizeBytes = 0,
    this.extension = '',
  });

  final String name;
  final String path;
  final int sizeBytes;
  final String extension;

  bool get hasPath => path.isNotEmpty;
}

/// 文件选择。作业上传、课件导入走这里。
class FilePickerService {
  const FilePickerService();

  Future<List<PickedFileInfo>> pickFiles({
    List<String> allowedExtensions = const [],
  }) async {
    final files = await FilePicker.pickFiles(
      type: allowedExtensions.isEmpty ? FileType.any : FileType.custom,
      allowedExtensions: allowedExtensions.isEmpty ? null : allowedExtensions,
    );
    return files
        .map(
          (file) => PickedFileInfo(
            name: file.name,
            path: file.path ?? '',
            sizeBytes: file.lengthSync() ?? 0,
            extension: file.extension ?? '',
          ),
        )
        .toList();
  }

  /// 选一个文件夹。设置页的「下载位置」和「每次都问」都走它。
  ///
  /// 用户取消时返回 null，调用方要当成「不下载」而不是「下载到默认目录」。
  Future<String?> pickDirectory({String? initialDirectory}) =>
      FilePicker.getDirectoryPath(initialDirectory: initialDirectory);
}
