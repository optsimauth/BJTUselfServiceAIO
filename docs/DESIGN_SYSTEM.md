# 设计系统（DESIGN_SYSTEM）

规则一句话：**页面里不出现裸数字**。间距、圆角、字号、颜色都从 `lib/shared/theme/` 取。
`test/design_token_lint_test.dart` 会把违规挡在 CI 之外。

## 1. 间距刻度 —— `AppSpacing`

代码位置：`lib/shared/theme/spacing.dart:5`

| Token | 值 | 用在哪 |
| --- | --- | --- |
| `AppSpacing.xs` | 4 | 图标与文字之间、徽标内边距、竖条之间的缝 |
| `AppSpacing.sm` | 8 | 同一组元素内部、chip 之间、列表项之间 |
| `AppSpacing.md` | 12 | 卡片内的次级块、表单行间距、弹层内容边距 |
| `AppSpacing.lg` | 16 | 卡片内边距、页面左右留白（`gutter`） |
| `AppSpacing.xl` | 24 | 分组标题上边距、大块之间 |
| `AppSpacing.xxl` | 32 | 页面级留白（如登录页标题上方） |
| `AppSpacing.gutter` | 16 | 页面左右留白常量，等价于 `lg` |
| `AppSpacing.stack` | 12 | 卡片之间的竖向间距，等价于 `md` |
| `AppSpacing.card` | `all(16)` | 卡片内边距默认值，`AppCard` 构造函数默认参数 |
| `AppSpacing.page` | `symmetric(horizontal: 16)` | 页面级左右留白 |

刻度规则：只用这 6 档；需要新值时先证明 6 档都不行，再加档并更新本文档。

## 2. 圆角刻度 —— `AppRadius`

代码位置：`lib/shared/theme/spacing.dart:22`。值本身是 `BorderRadius`，页面里直接
`borderRadius: AppRadius.lg`，不再出现 `BorderRadius.circular(16)`。

| Token | 值 | 用在哪 |
| --- | --- | --- |
| `AppRadius.bar` | 2 | 课程色条、进度条 |
| `AppRadius.xs` | 4 | 列表行内高亮块 |
| `AppRadius.chip` | 6 | 徽章、小圆点标签 |
| `AppRadius.sm` | 8 | 输入框、小色块（课表格子、教室时间段格） |
| `AppRadius.badge` | 10 | 课表格子上的次级徽章 |
| `AppRadius.md` | 12 | 列表项、输入框、对话框按钮、SnackBar |
| `AppRadius.control` | 14 | FilledButton / OutlinedButton（见 `app_theme.dart` 按钮主题） |
| `AppRadius.lg` | 16 | 卡片（`cardTheme.shape`） |
| `AppRadius.sheet` | 20 | 对话框、底部弹层、摘要卡（`dialogTheme` / `bottomSheetTheme`） |

## 3. 触控目标 —— `AppTouch`

代码位置：`lib/shared/theme/spacing.dart:52`。`AppTouch.minimum = 44`。
视觉可以更小（星期胶囊 32），但命中区必须用 `ConstrainedBox(minWidth/minHeight: AppTouch.minimum)` 撑开。

## 4. 字号层级 —— `AppTypography`

代码位置：`lib/shared/theme/typography.dart`

| 层级 | 来源 | 说明 |
| --- | --- | --- |
| 全局倍率 | `AppTypography.scale = 1.18` | `AppTheme._build` 里乘到整个 textTheme 上 |
| 标题 | `titleLarge / titleMedium / labelLarge` | 自动 w600 + 等宽数字 |
| 正文 | `bodyMedium` | 等宽数字（成绩、排名、倒计时不跳宽） |
| 辅助 | `bodySmall`（height 1.4） | 副标题、说明文字 |
| 具名 | `AppTypography.cardTitle` (16) / `cardSubtitle` (13) / `captionMuted` (12) | 卡片内外复用 |
| 换算 | `AppTypography.size(base)` | 页面里要写字号时用它，自动乘 scale |
| 例外 | `AppTypography.sizeFixed(base)` | **不**乘 scale。只给两类：窄屏必须塞下的标签（星期缩写、格子里的小注）、要严格对齐的数字 |

## 5. Surface 与描边阶梯

代码位置：`lib/shared/theme/app_theme.dart`（主题装配）、`colors.dart`（品牌/状态色）

| 语义位 | 用途 | 来源 |
| --- | --- | --- |
| `surface` | 页面底色 | `ColorScheme.fromSeed`（`AppColors.brand` 打底） |
| `surfaceContainerLowest` | 输入框填充 | `inputDecorationTheme.fillColor` |
| `surfaceContainerLow` | 卡片底、底部弹层 | `cardTheme.color` / `bottomSheetTheme` |
| `surfaceContainerHigh` | 对话框底、筛选条底 | `dialogTheme.backgroundColor` |
| `surfaceContainerHighest` | 未选中的小徽标底 | 页面内按需取 |
| `outlineVariant` | 卡片描边、分隔线、输入框描边 | 1px；`dividerTheme` 同样走它 |
| `onSurface` / `onSurfaceVariant` | 正文 / 次要文字 | `AppTheme._build` 显式绑定，不靠 ThemeData 推导 |
| `onPrimary` / `onInverseSurface` | primary 卡上的文字 / SnackBar 文字 | 单独绑定，避免深底深字 |

## 6. 状态色语义 —— `AppColors`

代码位置：`lib/shared/theme/colors.dart`

| Token | 值 | 语义 |
| --- | --- | --- |
| `AppColors.brand` | `#1B5E9C` | 品牌主色，只用来生成 ColorScheme，不直接写进页面 |
| `AppColors.brandDark` | `#0E3A61` | 深色场景的品牌色 |
| `AppColors.success` | `#2E9E6B` | 已完成 / 已下载 / 空闲 |
| `AppColors.warning` | `#E8A33D` | 临期 / 提醒 |
| `AppColors.danger` | `#D9534F` | 失败 / 破坏性操作 |
| `AppColors.exam(scheme)` | 浅色 `#B25A00` / 深色 `#F5A524` | 考试。**两套值**，写死一个色必然有一边看不清 |
| `AppColors.forCourse(id)` | 8 色调色板 | 课程稳定取色；铺在上面的文字用 `AppColors.onAccent` |
| `AppColors.onAccent` | `#FFFFFF` | 铺在课程色 / primary 上的文字 |
| `AppColors.transparent` | `#00000000` | const 容器（如 `CalendarStyle`）里也要有名字 |

对比度底线：正文 ≥ 4.5:1（`test/app_visual_contrast_test.dart` 已断言）；
卡片描边与底色 ≥ 1.5:1。

## 7. 三态（加载 / 空 / 错误）

| 状态 | 组件 | 代码位置 |
| --- | --- | --- |
| 加载 | `AsyncView` + `AppLoading` | `lib/shared/widgets/async_view.dart`、`loading/app_loading.dart` |
| 空 | 页面内 `emptyBuilder` / 私有空态 | 各页（如 `EmptyScheduleView`、`courseware_page.dart` 空文件夹） |
| 错误 | `AppDialog.error` | `lib/shared/widgets/dialog/app_dialog.dart` |

约定：空态必须写「为什么空 + 下一步做什么」，不能只写「暂无数据」。

## 8. 响应式

| 断点 | 行为 | 代码位置 |
| --- | --- | --- |
| ≤ 1160 | 全宽，页面左右留白 16 | `lib/shared/widgets/page_width.dart` |
| > 1160 | 限宽 1160 居中，两侧画底色 | 同上（在 `app.dart` 里包住整个 Navigator） |
| 系统字号放大 | 夹到 1.3x，防密集表格溢出 | `app.dart` 的 `MediaQuery.withClampedTextScaling` |
| 桌面滚动 | 常驻滚动条，鼠标可拖动 | `AppScrollBehavior`（`app_theme.dart`） |

窄栏例外：登录页 `maxWidth: 460`（`login_page.dart:89`）是有意的窄表单，不属于 1160 体系。

## 9. 禁止清单

- 裸 `Colors.xxx`（含 `Colors.transparent` / `Colors.white`）
- 裸 `fontSize: 12`
- 裸 `BorderRadius.circular(16)`
- 硬编码 `EdgeInsets` 里的非零数字
- 新增第三方 UI 库或状态管理框架
- 放宽 `analysis_options.yaml` 的规则强度
