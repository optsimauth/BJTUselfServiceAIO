# UI 设计规范

本项目按外部设计规则约束 UI，再用共享主题落地。适用优先级为：Flutter 官方可访问性与响应式说明 → 下列已下载参考的硬性规则 → 本项目的视觉选择。项目文档用于记录选择，不代替外部规则，也不能用审计分数证明所有页面已经合规。

## 1. 外部依据与可追溯版本

主参考为 [Flutter Design Skill](https://github.com/priyeshchowta/flutter-design-skill/tree/7cb5cd35bfa241866ca8e3e5643a5929530358cd)，固定版本 `7cb5cd35bfa241866ca8e3e5643a5929530358cd`。仓库内保留原文、审计脚本与 MIT 许可证：

- `design-references/flutter-design/SKILL.md`：先读场景、定设计方向，再实施与渲染检查。
- `design-references/flutter-design/reference/craft-floor.md`：质量底线。
- `design-references/flutter-design/reference/platform/adaptive.md`：600/840/1200 窗口分级、48dp 触控目标、内容限宽。
- `design-references/flutter-design/reference/rules/`：`a11y-tap-target`、`a11y-text-scale-2x`、`a11y-contrast-text`、`a11y-contrast-ui`、`layout-rhythm`、`layout-card-soup`、`motion-reduce` 等具体规则。

补充参考为 [UI UX Pro Max](https://github.com/nextlevelbuilder/ui-ux-pro-max-skill/tree/d14efff8ed1faa4187f004f79926f428c8074ec7)，固定版本 `d14efff8ed1faa4187f004f79926f428c8074ec7`。保留的 `design-references/ui-ux-pro-max/flutter.csv` 用于核对 LayoutBuilder、输入标签、反馈和主题适配。

官方依据：

- [Flutter 响应式设计](https://docs.flutter.dev/ui/adaptive-responsive/general)：600 逻辑像素处切换底部导航与侧栏。
- [Flutter 响应式最佳实践](https://docs.flutter.dev/ui/adaptive-responsive/best-practices)：根据实际窗口和布局约束适配。
- [Flutter 可访问性](https://docs.flutter.dev/ui/accessibility)：触控、文字对比度、系统大字号和辅助功能。

## 2. 需要验证的硬指标

- 点击目标至少 48×48；视觉图标可以小，真实命中区域不能小。`AppTouch.minimum` 是共享值；导航与按钮通过实际 RenderBox 尺寸和点击回调测试。
- 系统字号放大到 2.0 后，主要文字换行或允许滚动；不全局截断 TextScaler，不用缩小正文来消除溢出。
- 正文与背景对比度至少 4.5:1；交互边框、焦点提示至少 3:1。对比度按 `(较亮相对亮度 + 0.05) / (较暗相对亮度 + 0.05)` 计算。分隔线、装饰性卡片边框不冒充交互边框。
- 组件从 ColorScheme 和 TextTheme 取色与字体，必须随浅深主题切换。页面间距、圆角复用 `shared/theme/spacing.dart`。
- 根据窗口约束切换导航，不使用设备类型判断。小于 600 使用底栏；600–1199 使用带标签侧栏；1200 起保留展开侧栏。这里用展开 NavigationRail 实现常驻文字导航，是针对仅有三个一级目的地的项目选择；参考中的大屏 permanent drawer 表达同一持续可见的导航意图，无需额外弹出抽屉。
- 尊重系统减少动画：课件展开、邮箱展开、成绩回顶的自定义动画读取 `MediaQuery.disableAnimationsOf`，平台组件继续使用框架行为。
- 输入框有持续可见的标签；加载期间保留操作反馈并禁用重复提交；空态与错误态给出原因和恢复入口。
- 正文避开系统安全区域；键盘出现时表单可滚动到主操作。

## 3. 项目视觉选择

视觉主参考更新为 [Flutter Shadcn UI](design-references/flutter-shadcn-ui/README.md)，版本 `4fe5440765d4faf1855f3a2c456052b4121b3424`。采用它的 Slate 中性色、细边框、小圆角与操作层级，使用现有 Material 组件实现；前述外部规则继续约束可访问性与响应式行为。

以下数值是本项目选择，不宣称是外部规范指定的唯一风格。整体方向为中文校园工具：安静、可扫读、突出下一步操作。设计参数为布局变化 4/10、动效 2/10、密度 5/10。

- 品牌种子 `#1B5E9C`，使用 Material 3 `tonalSpot` 生成浅深色强调色与状态色。阅读区域使用独立的 Slate 中性色，浅色页面 `#F4F6FA` / 白面板，深色页面 `#0B1120` / `#111B2E` 面板。修改品牌种子不改变阅读区域。
- 页面底色 `surface`；导航与卡片 `surfaceContainerLow`；服务图标容器 `surfaceContainer`。输入底色 `surfaceContainerLowest`、交互描边 `outline`、焦点描边 `primary`；装饰分隔线使用 `outlineVariant`。底栏与侧栏均以 `primaryContainer` 标记选中态。
- 复用本地 Noto Sans SC，无新增字体和 UI 依赖。TextTheme 的现有 1.18 基础字号倍率与系统 TextScaler 各承担自己的职责，不在页面继续叠乘。数字复用等宽数字特性。
- 间距为 4/8/12/16/24/32：同组紧凑、分组留白更大。首页与服务页内容区小于 600 留白 16，较宽时 24。
- 圆角按语义：小标记、输入、按钮、卡片、弹层分别复用 AppRadius；输入与按钮 8dp，卡片 12dp，弹层 16dp；主按钮与次按钮均用 control 圆角。
- 首页、服务正文最大宽度 840，登录表单最大宽度 440，均集中在 AppLayout。宽屏服务目录按实际内容区是否达到 600 排两列；大字号退回单列。
- 使用边框、留白和排版分组，避免每条内容都变成重复彩色卡片。不额外增加装饰动画。

Token 细则见 `DESIGN_SYSTEM.md`；产品方向见根目录 `DESIGN.md`。

## 4. 页面落实

- 登录：品牌说明 → 有明确标签的表单 → 主按钮 → 安全存储说明。密码不预填，支持回车提交和密码管理器。按钮加载时显示“正在处理…”，布局可随长文案和字号增高。
- 首页：日期与教学周 → 课表/作业快捷入口 → 下一节课 → 邮件和余额状态 → 周历与当日日程。课程名称、地点、教师和时间自然换行。状态条在大字号下竖排；未知数据明确显示未知。用户自选背景图只放顶部封面，正文保持实色背景。
- 服务：按“学业”“校园”分组，完整服务名称加一句用途。手机纵向、宽屏两列、大字号纵向；整行可点，分隔线对齐文字起点。
- 课表：保留周次与网格操作；命中区至少 48，课程文字使用随底色配对的前景色。
- 成绩、考试、作业：保留现有业务流程，统一摘要、筛选、列表层次；顶部摘要使用实色面板与细边框，正文 / 次文字随主题配对；筛选区域允许随字号增高或横滚，数字和状态用共同主题语义。
- 课件：搜索与统计在上、课程树在下，树层级靠缩进和底色区分；减少动画设置下立即展开。
- 邮箱：保留列表、详情、写信流程；长正文可滚动，展开动画尊重系统设置。
- 教室：星期与节次清晰分组，规划为空教室的主要操作；窄屏优先显示节次号。
- 设置：分组列表，主题选择放在标题下方并占满可用宽度，避免大字号挤压。危险操作仍需确认。

- 设置、账号与工具目录统一使用 `AppSection` 的标题、实色卡片和细分隔线；账号长资料放在标签下方，避免与右侧文字争抢空间。
- 教学楼、日志和项目动态也使用相同面板和页面留白；日志与动态页有明确返回入口。
- 普通列表内容限宽 840；课表、教室与邮箱限宽 1200；导航和弹层不受内容宽度限制。
- 通用错误、登录提示与兜底空态采用 `AppStatusView`；窄屏和大字号下可滚动到恢复按钮。
- 邮箱文件夹与邮件选中态统一使用 `primaryContainer`，日期选择器、菜单、浮动按钮及图标按钮跟随共享主题。

AppBar 保留必要的高频操作，图标有 tooltip；低频操作进菜单。避免在 AppBar 与正文重复堆放相同主操作，不以任意“动作数量上限”删除有用功能。

## 5. 文案与反馈

使用具体动词与可执行的恢复建议；不要只写“暂无数据”或裸错误码。省略号使用“…”；数字与单位需要可读的间隔，例如“32 座”“5 MB”。空态、加载与错误通过现有 AsyncView、AppLoading、AppDialog 处理，不静默消失。

## 6. 验证入口与边界

- `test/ui_compliance_test.dart`：599/600、839/840、1199/1200 断点，1.0/2.0 字号，导航命中区域与点击、按钮加载与长文案。
- `test/app_visual_contrast_test.dart`、`test/theme_switch_test.dart`：标准对比度公式、浅深色主题和真实切换。
- `test/ui_redesign_test.dart`：360×640、360×800、412×915、820×1180、1440×900；浅深色与 1.0/2.0 字号；登录、首页、服务目录及有数据的成绩、考试、作业、课件页面。业务页样例通过测试注入，应用 MockList.enabled 保持 false。
- `test/design_token_lint_test.dart`、`test/responsive_layout_test.dart`、`test/home_status_strip_test.dart`、教室相关测试：共享组件与页面回归。
- `UI_REVIEW=1 flutter test test/ui_redesign_test.dart --plain-name '<用例名>'`：输出实际 Flutter 渲染截图到 `build/ui-review/`，供目视复核。截图不是像素级 golden 断言。
- `dart run docs/design-references/flutter-design/scripts/audit.dart lib/features/`：静态启发式审计。零命中仍需运行测试并查看截图，不能等同于全应用可访问性认证。

最新实际执行范围和结果记录在 `UI_CONSISTENCY_REVIEW.md`，不把计划执行的检查写成已经通过。
