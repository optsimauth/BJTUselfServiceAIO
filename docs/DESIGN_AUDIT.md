# 设计审计（DESIGN_AUDIT）

审计对象：`lib/features` 下 16 个功能页 + 2 个共用展示组件 = 18 屏。
基准：`flutter/skills`（一致性基线）、`dickwu/apple-design-skill`（Apple HIG 原文对照）、
`kamranbekirovyz/skills · flutter-improve-design`（Flutter UI/UX 审阅 + 改动清单）。
约束：只在 presentation 层改；业务 / 网络 / 数据 / 路由 / 依赖不动。

级别含义：**P0** 影响可用性或无障碍底线，必须改；**P1** 明显影响观感/一致性；
**P2** 打磨项，可以排到下个迭代。

## 逐屏审计表

| 文件:行号 | HIG 章节 | 问题 | 具体改法 | 级别 |
| --- | --- | --- | --- | --- |
| lib/features/home/home_page.dart:447 | Typography / Dynamic Type | 星期标签写死 12px，且刻意不跟全局缩放；系统放大到 2x 时三字标签放不下 | 保持固定字号（该处是有意的），但改走 `AppTypography.sizeFixed(12)`，并在 docs/DESIGN_SYSTEM.md 记录例外理由 | P2 |
| lib/features/home/home_page.dart:515 | Layout / Spacing | 日历格 `cellMargin` 裸数字，桌面端格子间距和手机端不一致 | 改 `EdgeInsets.all(AppSpacing.xs)`，间距统一到刻度 | P1 |
| lib/features/home/home_page.dart:810 | Color / Contrast | 事件计数小圆点用 `onSurfaceVariant`，在 primary 卡上偏灰 | 跟随卡片前景色（`onPrimary` 语义位），不写死具体色值 | P2 |
| lib/features/homework/homework_page.dart:230 | Layout / Spacing | 作业卡头部固定 52 高，字号放大后顶出去 | 去掉固定高度，改 `ConstrainedBox(minHeight:)` + 上下内边距 | P1 |
| lib/features/homework/homework_page.dart:356 | Separators | `Divider(height: 1)` 在同一页出现两种分隔线粗细 | 统一 `dividerTheme`（1px + outlineVariant），页面内不再单独自定义 | P2 |
| lib/features/homework/homework_page.dart:308 | Color / Contrast | 左侧 1px 竖条用 `width: 1` 的 Container 当装饰线 | 保留，但颜色改走 `colorScheme.primary`，避免主题换色后残留灰条 | P2 |
| lib/features/grade/grade_page.dart:328 | Layout / Spacing | 表格单元之间用 4/8 的裸 SizedBox 撑开，列宽不统一 | 间距统一 `AppSpacing.sm`，列宽交给 `Table` 的 `FlexColumnWidth` | P1 |
| lib/features/grade/grade_page.dart:132 | Controls / Menus | 筛选用 `PopupMenuButton`，图标无 tooltip 说明筛的是哪一项 | 补 `tooltip`，并在菜单标题里写当前筛选值 | P1 |
| lib/features/grade/grade_page.dart:428 | Layout / Spacing | 分数徽标内边距 `(8, 4)` 是局部拍脑袋值 | 改 `AppSpacing.sm / AppSpacing.xs`，与首页徽标一致 | P2 |
| lib/features/exam/exam_page.dart:316 | Color / Contrast | 3px 竖条区分考试类型，颜色取自课程色板，浅色底对比不足 | 竖条与圆点改走 `AppColors.exam(scheme)`（浅深两套值） | P1 |
| lib/features/exam/exam_page.dart:289 | Layout / Spacing | 时间轴 `separatorBuilder` 固定 8px，纵线与节点对不齐 | 线与节点用同一个 `AppSpacing.sm` 变量，节点半径跟随线宽 | P2 |
| lib/features/classroom/classroom_page.dart:300 | Touch Targets | 星期胶囊 32x32，低于 44x44 命中区 | 视觉保持 32，用 `ConstrainedBox(minWidth/minHeight: AppTouch.minimum)` 撑开命中区 | P0 |
| lib/features/classroom/classroom_page.dart:524 | Touch Targets / Layout | 时间段格子固定 44 高，7 个格子横向排布时总宽超出 360 屏 | 高度改 `minHeight`，横向放进 `SingleChildScrollView` | P0 |
| lib/features/classroom/classroom_page.dart:539 | Typography | 格子内节次号 13px、时间 9px 写死 | 改 `AppTypography.size(13)` / `AppTypography.size(9)` | P1 |
| lib/features/course/course_schedule_page.dart:253 | Touch Targets | 周次箭头 `VisualDensity.compact` 把命中区压到 40x40 | 去掉 compact，用 `AppTouch.minimum` 兜底 | P0 |
| lib/features/course/course_schedule_page.dart:375 | Color / Contrast | 课程色条取自 `coursePalette` 中间饱和色，浅色底上白字对比不足 | 保留色相，文字色按底色亮度选 `AppColors.onAccent` / 深色 | P1 |
| lib/features/courseware/courseware_page.dart:679 | Lists / Actions | 文件行右侧三个动作并排，`ListTile` 的 trailing 在窄屏被压缩 | 窄屏收进 `PopupMenuButton`，宽屏保留平铺 | P1 |
| lib/features/courseware/courseware_page.dart:604 | Layout / Spacing | 树形缩进 `depth * 14` 硬编码，缩进一级不是刻度值 | 改 `depth * AppSpacing.md`，缩进层级与间距刻度对齐 | P2 |
| lib/features/email/email_page.dart:412 | Empty States | 空态用 80px 裸高度顶开，标题与说明没有层级差 | 空态统一成一个组件：图标 + 标题（titleMedium）+ 说明（bodySmall） | P1 |
| lib/features/email/email_page.dart:733 | Tables / Wide Content | 邮件详情用 `Table` + 横向滚动，列宽靠内容撑，桌面端右侧留白很大 | 桌面端给 `Table` 限宽（走 `PageWidth`）并左对齐 | P1 |
| lib/features/email/email_page.dart:723 | Layout / Spacing | 详情块内边距 `(12,0,12,14)` 是局部值 | 改 `AppSpacing.md`，与其他块的节奏一致 | P2 |
| lib/features/login/login_page.dart:89 | Layout | 表单限宽 460 是裸数字，与 `PageWidth.maxWidth(1160)` 不是同一套语言 | 保留（登录确实是窄栏），但在 DESIGN_SYSTEM 里登记为「窄栏」例外 | P2 |
| lib/features/login/login_page.dart:102 | Layout / Spacing | 标题到表单、表单到按钮之间的间距用 8/32 混用 | 统一 `AppSpacing.sm / AppSpacing.xxl` | P2 |
| lib/features/settings/settings_page.dart:183 | Lists / Sections | 分组标题靠 `_SectionHeader` 私有类，间距 20/8 是裸数字 | 改 `AppSpacing.xl / AppSpacing.sm`，并让分组标题色取 `colorScheme.primary` | P1 |
| lib/features/settings/settings_page.dart:310 | Color / Contrast | 「退出登录」整行用 error 色，列表里唯一一处红字，容易被当成状态 | 保留红色语义，但改成 `ListTile` 的 `enabled: false` + 二次确认，不用整行红 | P2 |
| lib/features/settings/settings_page.dart:337 | Feedback | 「关于」原来跳到「其他功能」页，语义错位 | 改为 App 自身介绍弹窗（版本号 + 能干什么 + 数据来源 + 开源地址） | P0 |
| lib/features/logs/logs_page.dart:87 | Typography | 日志正文用默认 `Text`，长行不换行，桌面端横向溢出 | 用 `SelectableText` + `TextOverflow` 或等宽字体 + 软换行 | P1 |
| lib/features/logs/logs_page.dart:79 | Feedback | 提示条没有图标，纯文字，弱提示/错误分不清 | 成功/失败用不同背景语义（inverseSurface / errorContainer） | P2 |
| lib/features/account/account_page.dart:77 | Lists | 个人信息整页 ListTile，没有分组标题也没有说明文字 | 加 `_SectionHeader('学籍信息')`，副标题用 `bodySmall` 弱化 | P2 |
| lib/features/other/other_function_page.dart:50 | Lists / Actions | 三个一次性动作没有说明副标题，用户不知道点下去会发生什么 | 每行补一句 `subtitle` 说明产物（如「导出 .ics，可导入系统日历」） | P1 |
| lib/features/space/space_page.dart:28 | Layout / Grid | 宫格列数固定，1280 宽下每格被拉得过大 | 列数按 `PageWidth` 宽度取 4/6/8 三档 | P1 |
| lib/features/detection/detection_page.dart:1 | — | 该页是纯跳转壳（40 行），没有独立视觉问题 | 无 | P2 |
| lib/features/webview/web_page.dart:1 | Navigation | WebView 页无返回/前进状态的可视反馈 | 底部工具条按钮在不可用时置灰（`onPressed: null`），并补 tooltip | P2 |
| lib/shared/components/calendar/schedule_calendar.dart:516 | Color / Contrast | 课程色块用色板中间色，浅色底下白色小字读不清 | 文字色按底色亮度取 `AppColors.onAccent` 或深色 | P1 |
| lib/shared/components/calendar/schedule_calendar.dart:516 | Layout / Spacing | 色块圆角裸 8 | 改 `AppRadius.sm` | P2 |
| lib/shared/widgets/cards/app_card.dart:16 | Layout / Spacing | 卡片内边距 16 写死在构造函数默认值里 | 默认值改 `AppSpacing.card`，保持全 app 单一来源 | P1 |

## 已落地的横切修复（本次会话）

1. 新增 token 层 `lib/shared/theme/spacing.dart`：`AppSpacing`（4/8/12/16/24/32）、
   `AppRadius`（2/4/6/8/10/12/14/16/20，按用途命名）、`AppTouch.minimum = 44`。
2. `AppTypography.sizeFixed()`：给「必须固定字号」的窄屏标签用，避免裸 `fontSize:`。
3. `AppColors.transparent` / `AppColors.onAccent`：消灭 `Colors.transparent`、`Colors.white`。
4. `lib/features` + `lib/shared/widgets|components` 全部间距/圆角/字号/颜色改走 token。
5. 新增 `test/design_token_lint_test.dart`：裸 `Colors.*`、裸 `fontSize:`、
   裸 `BorderRadius.circular(数字)`、硬编码 `EdgeInsets` 数字一律失败（无白名单）。
6. 新增 `test/responsive_layout_test.dart`：360x800 与 1280x900 双断点无 overflow。

## 响应式人工清单（自动化覆盖不到的部分）

整页 widget 测试跑不了：`ServiceLocator` 是私有构造的依赖图（数据库 / 网络 / 平台通道），
没有测试缝，而本次不允许改 `lib/app`、`lib/data`、`lib/services`。所以下面这些只能人工过：

- [ ] 首页：1280 宽下日历与「今日课」是否并排、是否出现超长单行
- [ ] 作业页：1280 宽下时间轴竖线与节点是否仍对齐
- [ ] 邮箱页：1280 宽下详情 `Table` 是否左对齐、右侧是否留白过大
- [ ] 教室页：360 宽下 7 个时间段格横向滚动是否顺手
- [ ] 深色模式：所有页面走一遍（课程色块、状态色、primary 卡上的白字）
