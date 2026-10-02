import '../../../core/state/data_sync_manager.dart';
import '../../../core/state/sync_result.dart';
import '../../../data/models/courseware/courseware_model.dart';

/// 课件树的纯计算部分：计数、搜索、按课程分组。
///
/// 全是顶层静态方法、不碰网络也不碰 widget —— 所以这一层的每个判断都能
/// 直接跑单元测试（见 `test/courseware_tree_test.dart`）。
abstract final class CoursewareTree {
  /// 把树摊平成一条节点列表（课程 / 文件夹 / 文件都算）。
  ///
  /// 变更检测是逐个节点按 identity 比的，所以得先摊平 —— 树里的父子关系
  /// 在比较时没有意义，「哪个节点还在不在」才是。
  static List<CoursewareNode> flatten(List<CoursewareNode> roots) => [
    for (final node in roots) ...[node, ...flatten(node.children)],
  ];

  /// 新旧两棵树在**节点**层面的差异。
  ///
  /// 用成绩 / 作业那一套 [DataSyncManager] 比较规则，语义保持一致：
  /// 新 id = 新增，远端没有的 id = 删除，名字或大小变了 = 变更。
  /// 这里不落库（store 留空）：课件的「库」是 preferences 里的 JSON 树，
  /// 写入由 CoursewareRepository.refreshTree 自己管。
  static List<DataChange<CoursewareNode>> detectChanges({
    required List<CoursewareNode> remote,
    required List<CoursewareNode> local,
  }) => _comparer.detectChanges(remote: remote, local: local);

  static final DataSyncManager<CoursewareNode> _comparer =
      DataSyncManager<CoursewareNode>(
        identity: (node) => node.identity,
        // 改名、换大小都算变更；只换了下载次数不算 —— 那是使用量，不是内容。
        changed: (current, previous) =>
            current.name != previous.name ||
            current.sizeText != previous.sizeText,
      );

  /// 变更详情弹层里的那一行：标题 + 变了的字段。
  static SyncChangeDetail describeChange(
    CoursewareNode node,
    CoursewareNode? previous,
    DataChangeKind kind,
  ) {
    final before = kind == DataChangeKind.added ? null : previous ?? node;
    final after = kind == DataChangeKind.deleted ? null : node;
    return SyncChangeDetail(
      kind: kind,
      // 课件是树，光有文件名看不出属于哪门课，前面带上课程名。
      title: '${node.course?.name ?? ''} · ${node.name}'.trim(),
      fields: [
        SyncFieldChange(
          label: '名称',
          before: before?.name ?? '',
          after: after?.name ?? '',
        ),
        SyncFieldChange(
          label: '大小',
          before: before?.sizeText ?? '',
          after: after?.sizeText ?? '',
        ),
      ],
    );
  }

  /// 树里第 [depth] 层往右缩进多少像素。
  ///
  /// 越顶级的目录越靠左 —— 没有缩进的话，子文件和父文件夹顶在同一列，
  /// 整棵树看着是平的，"这个文件属于哪一章" 全看不出来。
  /// 每层 16：一层就够分辨，5 层封顶（再深也不把文件名挤没了）。
  static double indentOf(int depth) => 16.0 * (depth > 5 ? 5 : depth);

  /// 整棵树里有几个文件（不含文件夹，也不含课程节点本身）。
  static int resourceCount(List<CoursewareNode> roots) =>
      roots.fold(0, (sum, root) => sum + filesOf(root).length);

  /// 某一门课下所有文件。课程节点自己不算。
  static List<CoursewareNode> filesOf(CoursewareNode node) => [
    for (final child in node.children)
      if (child.kind == CoursewareKind.res) child else ...filesOf(child),
  ];

  /// 某一门课下所有文件里还没下的。
  static List<CoursewareNode> pendingFilesOf(CoursewareNode node) =>
      filesOf(node).where((file) => !file.isDownloaded).toList(growable: false);

  /// 整棵树里还没下的文件数。
  static int pendingCount(List<CoursewareNode> roots) =>
      roots.fold(0, (sum, root) => sum + pendingFilesOf(root).length);

  /// 认路用的稳定标识集合。缓存「哪些展开过 / 哪些下过了」时用它当 key。
  static Set<String> identitiesOf(CoursewareNode node) => {
    node.identity,
    for (final child in node.children) ...identitiesOf(child),
  };

  /// 一份待下载的文件：文件本身 + 它在磁盘上该落的文件夹链。
  ///
  /// 落盘目录 = 用户选的根目录 + [folders] 逐层拼出来，所以平台的层级原样保留：
  /// 课程是第一个文件夹，文件夹往下逐层建，文件名自己不算一层。
  static List<CoursewareDownloadItem> downloadItemsOf(
    CoursewareNode root, {
    int maxDepth = 6,
    List<String> trail = const [],
  }) {
    if (maxDepth <= 0) return const [];
    final here = trail.isEmpty ? [if (root.name.isNotEmpty) root.name] : trail;
    return [
      for (final child in root.children) ..._itemsOf(child, here, maxDepth),
    ];
  }

  /// 一个子节点展开成哪些待下载项。
  ///
  /// 单独抽出来是因为写成嵌套 collection-if 时 `else` 会绑到里层那个 if 上，
  /// 结果文件夹整支被吞掉 —— 只有课程根下直挂的文件进得来。
  static List<CoursewareDownloadItem> _itemsOf(
    CoursewareNode child,
    List<String> here,
    int maxDepth,
  ) {
    if (child.kind == CoursewareKind.res) {
      if (!child.canDownload || child.isDownloaded) return const [];
      return [CoursewareDownloadItem(file: child, folders: here)];
    }
    return downloadItemsOf(
      child,
      maxDepth: maxDepth - 1,
      trail: [...here, if (child.name.isNotEmpty) child.name],
    );
  }

  /// 一个节点在树里从课程到它上面那层的文件夹名链（不含它自己）。
  static List<String> foldersOf(List<CoursewareNode> roots, String identity) {
    final chain = chainOf(roots, identity);
    if (chain.length <= 1) return const [];
    return chain
        .take(chain.length - 1)
        .map((node) => node.name)
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
  }

  /// 一层文件夹名转成能落盘的一段路径。
  ///
  /// 平台文件名里可能有 `\ / : * ? " < > |`，Windows 和部分安卓文件系统直接拒收，
  /// 所以在拼路径前把非法字符换成全角同义字（比删掉更有用：「第1章:讲义」仍能读出来）。
  static String safeSegment(String name) {
    const replacements = {
      r'\': '＼',
      '/': '／',
      ':': '：',
      '*': '＊',
      '?': '？',
      '"': '＂',
      '<': '＜',
      '>': '＞',
      '|': '｜',
    };
    final buffer = StringBuffer();
    for (final char in name.split('')) {
      buffer.write(replacements[char] ?? char);
    }
    final cleaned = buffer.toString().trim();
    // Windows 不允许以点或空格结尾，也不允许纯 `.` / `..`。
    final trimmed = cleaned.replaceAll(RegExp(r'[ .]+$'), '');
    if (trimmed.isEmpty || trimmed == '.' || trimmed == '..') return '_';
    return trimmed;
  }

  /// 搜文件名。[query] 为空返回空列表 —— 空搜索不是「全部命中」。
  ///
  /// 大小写不敏感，中英文都能命中；课程名也算命中范围，因为学生常常
  /// 拿课名当关键词（「高数课件」）。命中文件夹名时列出该文件夹下的所有
  /// 文件（文件夹自己不当结果）—— 学生搜「第一章」是想看第一章的课件，
  /// 不是想要一个点不动的文件夹。
  static List<CoursewareSearchResult> search(
    List<CoursewareNode> roots,
    String query,
  ) {
    final keyword = query.trim().toLowerCase();
    if (keyword.isEmpty) return const [];
    final results = <CoursewareSearchResult>[];
    for (final root in roots) {
      _collectMatches(
        node: root,
        keyword: keyword,
        trail: const [],
        results: results,
      );
    }
    return results;
  }

  /// 一个搜索结果在树里的位置。
  ///
  /// 搜索结果是一份扁平列表，不带路径就没法告诉用户「这个文件在哪」，
  /// 所以结果里直接把 [path] 带上：课程 -> ... -> 所在文件夹（不含文件自己）。
  static void _collectMatches({
    required CoursewareNode node,
    required String keyword,
    required List<String> trail,
    required List<CoursewareSearchResult> results,
  }) {
    if (node.kind == CoursewareKind.res) {
      if (_matches(node, keyword)) {
        results.add(CoursewareSearchResult(node: node, path: trail));
      }
      return; // 文件没有子节点，到此为止
    }
    final next = [...trail, node.name];
    if (node.kind == CoursewareKind.bag && _nameMatches(node, keyword)) {
      // 命中的是文件夹名：整个文件夹都算命中，里面的文件全列出来。
      // 文件夹自己不是结果（学生要的是能下的文件），所以直接展开子层。
      _collectAllFiles(folder: node, folderPath: next, results: results);
      return;
    }
    for (final child in node.children) {
      _collectMatches(
        node: child,
        keyword: keyword,
        trail: next,
        results: results,
      );
    }
  }

  /// 把一个文件夹（含其下所有层）里的文件全收起。[folderPath] 是文件夹自己的路径。
  static void _collectAllFiles({
    required CoursewareNode folder,
    required List<String> folderPath,
    required List<CoursewareSearchResult> results,
  }) {
    for (final child in folder.children) {
      if (child.kind == CoursewareKind.res) {
        results.add(CoursewareSearchResult(node: child, path: folderPath));
      } else {
        _collectAllFiles(
          folder: child,
          folderPath: [...folderPath, child.name],
          results: results,
        );
      }
    }
  }

  /// 从根到 [identity] 命中的那条链，按「根 -> 叶」排序，含命中节点自己。
  ///
  /// 搜索结果是一条扁平列表，不带这层信息就没法「跳回它所在的位置」——
  /// 点一下搜索结果要能把它上面所有文件夹都打开，光记住 identity 不够，
  /// 得知道中间隔着哪几层。
  static List<CoursewareNode> chainOf(
    List<CoursewareNode> roots,
    String identity,
  ) {
    for (final root in roots) {
      final found = _chainOf(root, identity);
      if (found != null) return found;
    }
    return const [];
  }

  static List<CoursewareNode>? _chainOf(CoursewareNode node, String identity) {
    if (node.identity == identity) return [node];
    for (final child in node.children) {
      final found = _chainOf(child, identity);
      if (found != null) return [node, ...found];
    }
    return null;
  }

  /// 深度优先走一遍树。[onVisit] 返回 false 表示不再往下进。
  static void walk({
    required CoursewareNode node,
    required bool Function(CoursewareNode node, List<String> trail) onVisit,
    List<String> trail = const [],
  }) {
    if (!onVisit(node, trail)) return;
    final next = [...trail, node.name];
    for (final child in node.children) {
      walk(node: child, onVisit: onVisit, trail: next);
    }
  }

  /// 给一组根节点建一张「identity -> 节点」的表。
  static Map<String, CoursewareNode> indexOf(List<CoursewareNode> roots) {
    final index = <String, CoursewareNode>{};
    void collect(CoursewareNode node) {
      index[node.identity] = node;
      for (final child in node.children) {
        collect(child);
      }
    }

    for (final root in roots) {
      collect(root);
    }
    return index;
  }

  /// 把 [roots] 里 identity 命中的节点标成「已下载到 [path]」。
  ///
  /// 下载是按文件走的，但列表上要能看到状态，所以结果得整棵树一起交回去。
  static List<CoursewareNode> markDownloaded(
    List<CoursewareNode> roots,
    Map<String, String> downloaded,
  ) {
    if (downloaded.isEmpty) return roots;
    return roots.map((root) => _mark(root, downloaded)).toList(growable: false);
  }

  /// 标记是自底向上重建的，但只有真变了才换新对象 —— 没变的子树原样返回。
  ///
  /// 「变了没有」只能看引用：子节点长度永远等于原长度，拿长度比等于什么都没比，
  /// 那样重建出来的子树会被整个丢掉，标记永远传不上去。
  static CoursewareNode _mark(
    CoursewareNode node,
    Map<String, String> downloaded,
  ) {
    final path = downloaded[node.identity];
    var changed = path != null && path != node.downloadedPath;
    final children = <CoursewareNode>[];
    for (final child in node.children) {
      final marked = _mark(child, downloaded);
      if (!identical(marked, child)) changed = true;
      children.add(marked);
    }
    if (!changed) return node;
    return node.copyWith(
      children: children,
      downloadedPath: path ?? node.downloadedPath,
    );
  }

  static bool _matches(CoursewareNode file, String keyword) {
    if (_nameMatches(file, keyword)) return true;
    final course = file.course?.name.toLowerCase() ?? '';
    return course.contains(keyword);
  }

  static bool _nameMatches(CoursewareNode node, String keyword) =>
      node.name.toLowerCase().contains(keyword);
}

/// 一份待下载的文件 + 它的目标文件夹链。见 [CoursewareTree.downloadItemsOf]。
class CoursewareDownloadItem {
  const CoursewareDownloadItem({required this.file, required this.folders});

  final CoursewareNode file;

  /// 从课程到所在文件夹，不含文件名自己。
  final List<String> folders;
}

/// 一条搜索结果：命中的文件 + 它在树里的路径。
class CoursewareSearchResult {
  const CoursewareSearchResult({required this.node, required this.path});

  final CoursewareNode node;

  /// 从课程到所在文件夹，不含 [node] 自己。
  final List<String> path;

  /// 给界面显示的一行路径。空路径（直接挂在课程下）就只写课程名。
  String get location => path.isEmpty ? '课程根目录' : path.join(' / ');
}

/// 一门课在列表里的统计。顶部那张卡片直接用它。
class CoursewareCourseStat {
  const CoursewareCourseStat({
    required this.course,
    required this.total,
    required this.downloaded,
  });

  final CoursewareNode course;

  /// 这门课下一共有几个文件。
  final int total;

  /// 已经下过几个。
  final int downloaded;

  int get pending => total - downloaded;

  /// 门上还剩几个文件。空课程写 0。
  int get directChildren => course.children.length;

  /// 下完没有。没文件时算「下完了」，别让空课程永远显示「还剩 0 个」。
  bool get isComplete => pending <= 0;
}
