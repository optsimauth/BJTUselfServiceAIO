import 'package:flutter/foundation.dart';

import '../course/platform_course.dart';

/// 课件树里一个节点是什么。
///
/// 平台的资源树只有两种实体：文件夹（Bag）和文件（Res）。这里把「课程」也
/// 算成一种，因为它在旧代码里同样是树的一层（`CoursewareNode.course`）。
enum CoursewareKind { course, bag, res }

extension CoursewareKindX on CoursewareKind {
  bool get isFolder => this == CoursewareKind.bag;
}

/// 课件树的一个节点。
///
/// 旧项目是 `CoursewareNode(course, res, bag, children)` 四个可空字段拼的，
/// 取名字要一串 `when`；这里把名字、类型、下载地址都摊平成确定值，
/// 界面上想显示什么直接读就行。
@immutable
class CoursewareNode {
  const CoursewareNode({
    required this.id,
    required this.name,
    required this.kind,
    this.rpId = '',
    this.extension = '',
    this.sizeText = '',
    this.teacherName = '',
    this.updatedAt = '',
    this.downloadCount = 0,
    this.course,
    this.children = const [],
    this.downloadedPath,
  });

  /// 平台主键。文件夹是 `bag.id`，文件是 `res.resId`，课程是平台课程主键。
  final String id;

  final String name;

  final CoursewareKind kind;

  /// 文件的 `rpId`。下载地址要拿它去 `rpinfoDownloadUrl` 换，只有文件有。
  final String rpId;

  /// 扩展名（`extName`），平台给的是 `pdf` 这种不带点的形式。
  final String extension;

  /// 文件大小（`rpSize`）。平台给的是已经格式化好的文本，缺失就是空串。
  final String sizeText;

  /// 上传者（`teacherName`）。
  final String teacherName;

  /// 上传时间（`inputTime`），原样显示。
  final String updatedAt;

  /// 下载次数（`downloadNum`）。
  final int downloadCount;

  /// 归属课程。根节点自己就是课程。
  final PlatformCourse? course;

  final List<CoursewareNode> children;

  /// 本地已下载路径；为空表示没下过。
  final String? downloadedPath;

  bool get isFolder => kind.isFolder;

  /// 能下载吗：只有文件能，而且得有 `rpId`。
  bool get canDownload => kind == CoursewareKind.res && rpId.isNotEmpty;

  bool get isDownloaded => downloadedPath != null && downloadedPath!.isNotEmpty;

  /// 文件夹下面还剩几个没下的。空文件夹返回 0。
  int get pendingCount => children.fold(
    0,
    (sum, child) => sum + (child.isDownloaded ? 0 : child.pendingCount),
  );

  /// 认路用的稳定标识：课程用 `course-<主键>`，文件夹用 `bag-<id>`，
  /// 文件用 `res-<id>`。
  ///
  /// 前缀不能省：课程主键和 `resId` 都是平台自己的小整数，不加前缀会撞。
  /// 而且必须用 `kind.name` 而不是 `'$kind'` —— 后者会拼出
  /// `CoursewareKind.res`，多出一段枚举类名。
  String get identity =>
      kind == CoursewareKind.course ? 'course-$id' : '${kind.name}-$id';

  /// 深度优先展平（含自己），给搜索和统计用。
  List<CoursewareNode> flatten() => [
    this,
    for (final child in children) ...child.flatten(),
  ];

  CoursewareNode copyWith({
    String? id,
    String? name,
    CoursewareKind? kind,
    String? rpId,
    String? extension,
    String? sizeText,
    String? teacherName,
    String? updatedAt,
    int? downloadCount,
    PlatformCourse? course,
    List<CoursewareNode>? children,
    String? downloadedPath,
  }) => CoursewareNode(
    id: id ?? this.id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    rpId: rpId ?? this.rpId,
    extension: extension ?? this.extension,
    sizeText: sizeText ?? this.sizeText,
    teacherName: teacherName ?? this.teacherName,
    updatedAt: updatedAt ?? this.updatedAt,
    downloadCount: downloadCount ?? this.downloadCount,
    course: course ?? this.course,
    children: children ?? this.children,
    downloadedPath: downloadedPath ?? this.downloadedPath,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind.name,
    'rpId': rpId,
    'extension': extension,
    'sizeText': sizeText,
    'teacherName': teacherName,
    'updatedAt': updatedAt,
    'downloadCount': downloadCount,
    'downloadedPath': downloadedPath,
    'course': course == null
        ? null
        : {
            'id': course!.id,
            'courseNum': course!.courseNum,
            'name': course!.name,
            'teacherName': course!.teacherName,
            'teacherId': course!.teacherId,
            'fzId': course!.fzId,
            'semesterCode': course!.semesterCode,
          },
    'children': children.map((child) => child.toJson()).toList(),
  };

  factory CoursewareNode.fromJson(Map<String, dynamic> json) => CoursewareNode(
    id: '${json['id'] ?? ''}',
    name: '${json['name'] ?? ''}',
    kind: CoursewareKind.values.firstWhere(
      (kind) => kind.name == json['kind'],
      orElse: () => CoursewareKind.res,
    ),
    rpId: '${json['rpId'] ?? ''}',
    extension: '${json['extension'] ?? ''}',
    sizeText: '${json['sizeText'] ?? ''}',
    teacherName: '${json['teacherName'] ?? ''}',
    updatedAt: '${json['updatedAt'] ?? ''}',
    downloadCount: (json['downloadCount'] as num?)?.toInt() ?? 0,
    downloadedPath: json['downloadedPath'] as String?,
    course: _courseOf(json['course']),
    children: (json['children'] as List<dynamic>? ?? const [])
        .whereType<Map<dynamic, dynamic>>()
        .map((child) => CoursewareNode.fromJson(child.cast<String, dynamic>()))
        .toList(),
  );

  static PlatformCourse? _courseOf(Object? raw) {
    if (raw is! Map) return null;
    final json = raw.cast<String, dynamic>();
    final id = (json['id'] as num?)?.toInt() ?? 0;
    if (id == 0) return null;
    return PlatformCourse(
      id: id,
      courseNum: '${json['courseNum'] ?? ''}',
      name: '${json['name'] ?? ''}',
      teacherName: '${json['teacherName'] ?? ''}',
      teacherId: '${json['teacherId'] ?? ''}',
      fzId: '${json['fzId'] ?? ''}',
      semesterCode: '${json['semesterCode'] ?? ''}',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CoursewareNode && other.identity == identity;

  @override
  int get hashCode => identity.hashCode;

  @override
  String toString() => 'CoursewareNode($kind, $id, $name)';
}
