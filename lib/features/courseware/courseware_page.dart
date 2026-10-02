import 'package:flutter/material.dart';

import '../../app/service_locator.dart';
import '../../core/model/async_state.dart';
import '../../data/models/courseware/courseware_model.dart';
import '../../data/repositories/courseware_repository.dart';
import '../../shared/theme/colors.dart';
import '../../shared/theme/spacing.dart';
import '../../shared/theme/typography.dart';
import '../../shared/widgets/async_view.dart';
import '../../shared/widgets/buttons/app_buttons.dart';
import '../../shared/widgets/dialog/app_dialog.dart';
import 'courseware_controller.dart';
import 'courseware_tree.dart';

/// 课件页。旧项目 CoursewareScreen.kt（866 行）。
///
/// 层级（从外到里，一层只回答一个问题）：
/// - [_CoursewareHeader] 回答「我还欠多少」：三格统计 + 一条进度 + 搜索框；
/// - 一门课一张 [_CourseCard]，课程是第一层，展开后是它的资源树；
/// - 树里 [_FolderBlock] 是第二层（圆角底 + 左侧引导线），[_FileRow] 是第三层
///   （裸行 + 带色图标），层与层靠底色深浅和连线区分，不靠一圈套一圈的卡片；
/// - 搜索态是一份扁平列表，每行自带路径，点一下跳回树里的位置。
///
/// 展开手感全页共用 [_expandDuration] / [_expandCurve]。
class CoursewarePage extends StatefulWidget {
  const CoursewarePage({super.key, this.repository});

  /// 数据来源。不传就从 [ServiceScope] 拿，测试里注入内存实现。
  final CoursewareRepository? repository;

  @override
  State<CoursewarePage> createState() => _CoursewarePageState();
}

/// 展开动画。全页一份，课程和文件夹才会是同一个节奏。
const Duration _expandDuration = Duration(milliseconds: 220);
const Curve _expandCurve = Curves.easeOutCubic;

class _CoursewarePageState extends State<CoursewarePage> {
  late final CoursewareController _controller;
  final TextEditingController _searchBox = TextEditingController();

  /// 每个树节点的锚点。搜索结果点「定位」之后要滚到那一行，
  /// 滚动得先有个 BuildContext，所以每行给自己留一个 GlobalKey。
  final Map<String, GlobalKey> _anchors = <String, GlobalKey>{};

  /// controller 是不是这个页面自己建的（不是就别 dispose，单例归 ServiceLocator 管）。
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    final locator = ServiceScope.of(context);
    // 默认用 ServiceLocator 里那个常驻 controller：树已经在内存里，进页面直接显示。
    // 传了 repository 的（测试）才自己建一个，并且由页面负责 dispose。
    _ownsController = widget.repository != null;
    _controller = _ownsController
        ? CoursewareController(repository: widget.repository!)
        : locator.coursewareController;
    // 后台悄悄换新：已经有内容就不再切成转圈（见 CoursewareController.refresh）。
    _controller.refresh();
  }

  @override
  void dispose() {
    _searchBox.dispose();
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  /// 同一行每次重建都用同一个 key，元素才能被复用、才能记住滚动位置。
  GlobalKey anchorOf(String identity) =>
      _anchors.putIfAbsent(identity, () => GlobalKey(debugLabel: identity));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        title: const Text('课件'),
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) => Row(
              children: [
                if (_controller.isSearching)
                  IconButton(
                    tooltip: '退出搜索',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _searchBox.clear();
                      _controller.clearSearch();
                    },
                  ),
                IconButton(
                  tooltip: '刷新',
                  onPressed: _controller.state is AsyncLoading
                      ? null
                      : _controller.refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) => AsyncView<List<CoursewareNode>>(
          state: _controller.state,
          onRetry: _controller.refresh,
          loadingMessage: '正在拉取课程资源…',
          isEmpty: (_) => _controller.isEmpty,
          emptyBuilder: (_) => const EmptyCoursewareView(),
          builder: (context, _) => _CoursewareBody(
            controller: _controller,
            box: _searchBox,
            anchorOf: anchorOf,
            onDownloadFile: _downloadFile,
            onDownloadAll: _downloadAll,
            onDownloadCalendar: _downloadCalendar,
            onRevealFile: _revealFile,
          ),
        ),
      ),
    );
  }

  /// 从搜索结果跳回树里那个文件：展开路径上的每一层，再滚到它那一行。
  ///
  /// 光展开是不够的 —— 文件可能在屏幕外，用户会觉得「点了没反应」。
  /// 滚不动（还没建出来 / 已离开页面）就只当展开过了，不能把异常抛给用户。
  Future<void> _revealFile(CoursewareNode file) async {
    _controller.reveal(file);
    _searchBox.clear();
    _controller.clearSearch();
    await WidgetsBinding.instance.endOfFrame;
    final target = _anchors[file.identity]?.currentContext;
    if (target == null || !target.mounted) return;
    await Scrollable.ensureVisible(
      target,
      duration: _expandDuration,
      curve: _expandCurve,
      alignment: 0.25,
    );
  }

  Future<void> _downloadFile(CoursewareNode file) async {
    try {
      await _controller.download(file);
    } catch (error) {
      if (!mounted) return;
      await AppDialog.error(context, error);
    }
  }

  Future<void> _downloadAll(CoursewareNode node) async {
    try {
      final summary = await _controller.downloadAll(node);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            summary.failed == 0
                ? '已保存 ${summary.succeeded} 个文件'
                : '保存 ${summary.succeeded} 个，${summary.failed} 个失败',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      await AppDialog.error(context, error);
    }
  }

  Future<void> _downloadCalendar(CoursewareNode courseNode) async {
    try {
      await _controller.downloadTeachingCalendar(courseNode);
    } catch (error) {
      if (!mounted) return;
      await AppDialog.error(context, error);
    }
  }
}

/// 主体：搜索态给扁平结果，浏览态给头部 + 课程树。头部两种状态共用一块。
class _CoursewareBody extends StatelessWidget {
  const _CoursewareBody({
    required this.controller,
    required this.box,
    required this.anchorOf,
    required this.onDownloadFile,
    required this.onDownloadAll,
    required this.onDownloadCalendar,
    required this.onRevealFile,
  });

  final CoursewareController controller;
  final TextEditingController box;
  final GlobalKey Function(String identity) anchorOf;
  final ValueChanged<CoursewareNode> onDownloadFile;
  final ValueChanged<CoursewareNode> onDownloadAll;
  final ValueChanged<CoursewareNode> onDownloadCalendar;
  final ValueChanged<CoursewareNode> onRevealFile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CoursewareHeader(controller: controller, box: box),
        Expanded(
          child: controller.isSearching
              ? _SearchResults(
                  results: controller.results,
                  query: controller.query,
                  isDownloaded: controller.isDownloaded,
                  isDownloading: controller.isDownloading,
                  onDownload: onDownloadFile,
                  onReveal: onRevealFile,
                  onClearSearch: controller.clearSearch,
                )
              : _TreeView(
                  controller: controller,
                  anchorOf: anchorOf,
                  onDownloadFile: onDownloadFile,
                  onDownloadAll: onDownloadAll,
                  onDownloadCalendar: onDownloadCalendar,
                ),
        ),
      ],
    );
  }
}

/// 顶部：只有搜索框（和出错时的错误行）。
class _CoursewareHeader extends StatelessWidget {
  const _CoursewareHeader({required this.controller, required this.box});

  final CoursewareController controller;
  final TextEditingController box;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: AppRadius.lg,
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (controller.lastError != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              controller.lastError!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.captionMuted.copyWith(
                color: AppColors.danger,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          TextField(
            key: const ValueKey('courseware-search'),
            controller: box,
            onChanged: controller.search,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              isDense: true,
              hintText: '搜课件名 / 课程名',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: controller.isSearching
                  ? IconButton(
                      tooltip: '清空',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () {
                        box.clear();
                        controller.clearSearch();
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.md,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 浏览态：每门课一张卡，展开就是它的资源树。
class _TreeView extends StatelessWidget {
  const _TreeView({
    required this.controller,
    required this.anchorOf,
    required this.onDownloadFile,
    required this.onDownloadAll,
    required this.onDownloadCalendar,
  });

  final CoursewareController controller;
  final GlobalKey Function(String identity) anchorOf;
  final ValueChanged<CoursewareNode> onDownloadFile;
  final ValueChanged<CoursewareNode> onDownloadAll;
  final ValueChanged<CoursewareNode> onDownloadCalendar;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          for (final course in controller.roots)
            Padding(
              key: ValueKey('courseware-${course.identity}'),
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: _CourseCard(
                course: course,
                controller: controller,
                anchorOf: anchorOf,
                onDownloadFile: onDownloadFile,
                onDownloadAll: onDownloadAll,
                onDownloadCalendar: onDownloadCalendar,
              ),
            ),
        ],
      ),
    );
  }
}

/// 一门课。展开后是动作行 + 它的资源树。
class _CourseCard extends StatelessWidget {
  const _CourseCard({
    required this.course,
    required this.controller,
    required this.anchorOf,
    required this.onDownloadFile,
    required this.onDownloadAll,
    required this.onDownloadCalendar,
  });

  final CoursewareNode course;
  final CoursewareController controller;
  final GlobalKey Function(String identity) anchorOf;
  final ValueChanged<CoursewareNode> onDownloadFile;
  final ValueChanged<CoursewareNode> onDownloadAll;
  final ValueChanged<CoursewareNode> onDownloadCalendar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final expanded = controller.isExpanded(course);
    final pending = controller.pendingOf(course);
    final total = controller.totalOf(course);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => controller.toggle(course),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          course.name.isEmpty ? '未命名课程' : course.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _subtitle(course.course?.teacherName ?? '', total),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.captionMuted.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: '下载全部课件',
                    icon: const Icon(Icons.download_outlined),
                    onPressed: pending == 0 ? null : () => onDownloadAll(course),
                  ),
                  IconButton(
                    tooltip: '下载教学日历',
                    icon: const Icon(Icons.event_note_outlined),
                    onPressed: () => onDownloadCalendar(course),
                  ),
                  _Chevron(expanded: expanded),
                ],
              ),
            ),
          ),
          _ExpandSection(
            expanded: expanded,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(indent: AppSpacing.lg, endIndent: AppSpacing.lg),
                if (course.children.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      0,
                      AppSpacing.lg,
                      AppSpacing.lg,
                    ),
                    child: Text(
                      '这门课还没上传课件',
                      style: AppTypography.captionMuted.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  for (final child in course.children)
                    _NodeRow(
                      node: child,
                      depth: 0,
                      controller: controller,
                      anchorOf: anchorOf,
                      onDownloadFile: onDownloadFile,
                      onDownloadAll: onDownloadAll,
                    ),
                const SizedBox(height: AppSpacing.sm),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 「张三 · 12 份课件」/「12 份课件」。空课程只写「暂无课件」。
  String _subtitle(String teacher, int total) {
    if (total == 0) return teacher.isEmpty ? '暂无课件' : '$teacher · 暂无课件';
    return teacher.isEmpty ? '$total 份课件' : '$teacher · $total 份课件';
  }
}

/// 展开箭头。转一下比「突然多出一块 / 少一块」更清楚地说明是同一棵树在呼吸。
class _Chevron extends StatelessWidget {
  const _Chevron({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) => AnimatedRotation(
    turns: expanded ? 0.5 : 0,
    duration: _expandDuration,
    curve: _expandCurve,
    child: Icon(
      Icons.expand_more,
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );
}

/// 高度动画容器。课程和文件夹都用它，全页展开节奏一致。
class _ExpandSection extends StatelessWidget {
  const _ExpandSection({required this.expanded, required this.child});

  final bool expanded;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: _expandDuration,
    curve: _expandCurve,
    alignment: Alignment.topCenter,
    child: expanded
        ? child
        : const SizedBox(width: double.infinity, height: 0),
  );
}


/// 树里的一行。文件夹自己带「整包下载」，文件带「下载」。
class _NodeRow extends StatelessWidget {
  const _NodeRow({
    required this.node,
    required this.depth,
    required this.controller,
    required this.anchorOf,
    required this.onDownloadFile,
    required this.onDownloadAll,
  });

  final CoursewareNode node;
  final int depth;
  final CoursewareController controller;
  final GlobalKey Function(String identity) anchorOf;
  final ValueChanged<CoursewareNode> onDownloadFile;
  final ValueChanged<CoursewareNode> onDownloadAll;

  @override
  Widget build(BuildContext context) {
    if (node.kind == CoursewareKind.bag) {
      return _FolderBlock(
        node: node,
        depth: depth,
        controller: controller,
        anchorOf: anchorOf,
        onDownloadAll: onDownloadAll,
        onDownloadFile: onDownloadFile,
      );
    }
    return _FileRow(
      key: ValueKey('courseware-file-${node.identity}'),
      anchor: anchorOf(node.identity),
      depth: depth,
      file: node,
      downloaded: controller.isDownloaded(node),
      downloading: controller.isDownloading(node),
      onDownload: () => onDownloadFile(node),
    );
  }
}

/// 一层树。左边一根引导线把同一条链串起来：不靠缩进猜父子，靠连线看父子。
class _TreeGuide extends StatelessWidget {
  const _TreeGuide({required this.depth, required this.child});

  final int depth;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(left: CoursewareTree.indentOf(depth)),
    child: DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        child: child,
      ),
    ),
  );
}

/// 一个文件夹。展开后把子树用引导线串起来。
class _FolderBlock extends StatelessWidget {
  const _FolderBlock({
    required this.node,
    required this.depth,
    required this.controller,
    required this.anchorOf,
    required this.onDownloadAll,
    required this.onDownloadFile,
  });

  final CoursewareNode node;
  final int depth;
  final CoursewareController controller;
  final GlobalKey Function(String identity) anchorOf;
  final ValueChanged<CoursewareNode> onDownloadAll;
  final ValueChanged<CoursewareNode> onDownloadFile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final expanded = controller.isExpanded(node);
    final pending = controller.pendingOf(node);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(right: AppSpacing.sm),
          decoration: BoxDecoration(
            // 文件夹比文件重一档（底色 + 圆角 + 描边），文件行是裸的：层级一眼可分。
            color: expanded
                ? scheme.surfaceContainerHigh
                : scheme.surfaceContainerLowest,
            borderRadius: AppRadius.md,
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: InkWell(
            key: ValueKey('courseware-folder-${node.identity}'),
            borderRadius: AppRadius.md,
            onTap: () => controller.toggle(node),
            child: Padding(
              padding: const EdgeInsets.only(
                left: AppSpacing.sm,
                right: AppSpacing.xs,
                top: AppSpacing.sm,
                bottom: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Icon(
                    expanded ? Icons.folder_open : Icons.folder_outlined,
                    size: 20,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      node.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: '下载整个文件夹',
                    icon: const Icon(Icons.download_outlined),
                    onPressed: pending == 0 ? null : () => onDownloadAll(node),
                  ),
                  _Chevron(expanded: expanded),
                ],
              ),
            ),
          ),
        ),
        _ExpandSection(
          expanded: expanded,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final child in node.children)
                _TreeGuide(
                  depth: depth,
                  child: _NodeRow(
                    node: child,
                    depth: depth + 1,
                    controller: controller,
                    anchorOf: anchorOf,
                    onDownloadFile: onDownloadFile,
                    onDownloadAll: onDownloadAll,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 一个文件行。[location] 给了就显示（搜索态用），浏览态不重复写课程名。
class _FileRow extends StatelessWidget {
  const _FileRow({
    super.key,
    this.anchor,
    this.depth = 0,
    required this.file,
    required this.downloaded,
    required this.downloading,
    required this.onDownload,
    this.location,
    this.onReveal,
  });

  /// 滚动定位用的锚点。只有树里的行需要，搜索结果自己就是全部内容。
  final GlobalKey? anchor;

  /// 在树里的层级，0 = 不在树里（搜索结果）。用来缩进。
  final int depth;

  final CoursewareNode file;
  final bool downloaded;
  final bool downloading;
  final VoidCallback onDownload;
  final String? location;
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final meta = <String>[
      if (file.extension.isNotEmpty) file.extension.toUpperCase(),
      if (file.sizeText.isNotEmpty) file.sizeText,
    ].join(' · ');
    return KeyedSubtree(
      key: anchor,
      child: Padding(
        padding: EdgeInsets.only(left: CoursewareTree.indentOf(depth)),
        child: InkWell(
          borderRadius: AppRadius.md,
          // 搜索态点整行是「跳过去看」，下载交给右边的按钮；
          // 树里没地方可跳，点整行就是下载。下过的文件不再提供这两个动作。
          onTap: onReveal ?? (downloaded ? null : onDownload),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                _FileGlyph(extension: file.extension, downloaded: downloaded),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: downloaded ? scheme.onSurfaceVariant : null,
                        ),
                      ),
                      if (location != null || meta.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          location == null ? meta : '$location\n$meta',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.captionMuted.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                _FileAction(
                  downloaded: downloaded,
                  downloading: downloading,
                  onDownload: onDownload,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 文件右侧的动作：下过 = 绿勾，下着 = 转圈，没下 = 下载箭头。
class _FileAction extends StatelessWidget {
  const _FileAction({
    required this.downloaded,
    required this.downloading,
    required this.onDownload,
  });

  final bool downloaded;
  final bool downloading;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    if (downloading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      tooltip: downloaded ? '已下载' : '下载',
      icon: Icon(
        downloaded ? Icons.check_circle : Icons.download_outlined,
        color: downloaded ? AppColors.success : null,
      ),
      onPressed: downloaded ? null : onDownload,
    );
  }
}

/// 文件图标：色块 + 图标。扩展名决定颜色，一屏里 PDF / PPT / 视频能分开。
class _FileGlyph extends StatelessWidget {
  const _FileGlyph({required this.extension, required this.downloaded});

  final String extension;

  /// 下过的文件整个图标淡掉 —— 状态写在图上，不只靠右边那枚勾。
  final bool downloaded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = AppColors.badge(scheme, _accentOf(extension, scheme));
    return Opacity(
      opacity: downloaded ? 0.45 : 1,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: AppRadius.sm,
        ),
        child: Icon(_iconOf(extension), size: 18, color: colors.foreground),
      ),
    );
  }

  static IconData _iconOf(String extension) => switch (extension) {
    'pdf' => Icons.picture_as_pdf_outlined,
    'ppt' || 'pptx' => Icons.slideshow_outlined,
    'doc' || 'docx' => Icons.description_outlined,
    'xls' || 'xlsx' => Icons.table_chart_outlined,
    'mp4' || 'avi' || 'mkv' => Icons.movie_outlined,
    'mp3' || 'wav' => Icons.audiotrack_outlined,
    'zip' || 'rar' || '7z' => Icons.folder_zip_outlined,
    _ => Icons.insert_drive_file_outlined,
  };

  /// 一类文件一个身份色。全部取自 token / ColorScheme，深浅主题下都能读。
  static Color _accentOf(String extension, ColorScheme scheme) =>
      switch (extension) {
        'pdf' => AppColors.danger,
        'ppt' || 'pptx' => AppColors.warning,
        'doc' || 'docx' => AppColors.brand,
        'xls' || 'xlsx' => AppColors.success,
        'zip' || 'rar' || '7z' => scheme.tertiary,
        'mp3' || 'wav' => scheme.secondary,
        'mp4' || 'avi' || 'mkv' => scheme.primary,
        _ => scheme.outline,
      };
}

/// 搜索态：一份扁平结果，每行都带「它在哪」的路径。
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.results,
    required this.query,
    required this.isDownloaded,
    required this.isDownloading,
    required this.onDownload,
    required this.onReveal,
    required this.onClearSearch,
  });

  final List<CoursewareSearchResult> results;
  final String query;
  final bool Function(CoursewareNode node) isDownloaded;
  final bool Function(CoursewareNode node) isDownloading;
  final ValueChanged<CoursewareNode> onDownload;
  final ValueChanged<CoursewareNode> onReveal;
  final VoidCallback onClearSearch;

  @override
  Widget build(BuildContext context) {
    if (results.isEmpty) {
      return EmptyCoursewareView(
        message: '没找到「$query」',
        hint: '换个关键词试试',
        action: OutlinedButton.icon(
          onPressed: onClearSearch,
          icon: const Icon(Icons.close, size: 18),
          label: const Text('清空搜索'),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      key: const ValueKey('courseware-search-results'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      itemCount: results.length + 1,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.xs),
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Text(
              '${results.length} 条匹配 · 点一行跳回它在树里的位置',
              style: AppTypography.captionMuted.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          );
        }
        final result = results[index - 1];
        return _FileRow(
          key: ValueKey('courseware-search-${result.node.identity}'),
          file: result.node,
          location: result.location,
          downloaded: isDownloaded(result.node),
          downloading: isDownloading(result.node),
          onDownload: () => onDownload(result.node),
          onReveal: () => onReveal(result.node),
        );
      },
    );
  }
}

/// 空态。搜索没命中和真的一门课都没资源，两种话要分开说。
class EmptyCoursewareView extends StatelessWidget {
  const EmptyCoursewareView({super.key, this.message, this.hint, this.action});

  final String? message;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.folder_open_outlined,
                size: 28,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              message ?? '老师还没上传课件',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              hint ?? '上传后点右上角刷新',
              style: AppTypography.captionMuted.copyWith(
                color: scheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            if (action != null) ...[
              const SizedBox(height: AppSpacing.lg),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
