# 功能对齐审计（按原项目 git 历史逐条核对）

对象：`BJTUselfService/`（原 Compose 项目，本地 clone，287 个提交）。
方法：`git log` 取功能类提交与合并提交（PR），逐条读提交说明，再到 Flutter 代码里找对应实现与测试。
结论口径：**✅ 已复现**（有代码 + 有测试）／**⚠️ 部分**（行为有差异，差异已登记）／**❌ 未移植**（附理由）。

## 一、逐条核对表

| 原项目提交 / PR | 说明里的需求 | Flutter | 证据 |
| --- | --- | --- | --- |
| `5f875d5` (#37) | 适配新版 SSO（动态 OAuth 字段 + SM2） | ✅ | `sso_parser.dart`、`auth_api.dart`、`test/sso_login_test.dart` 23 项 |
| `42f1d57` | 「修复无法正确显示余额等基本信息」 | ✅（本轮补） | `status_api/status_parser/status_repository` + 首页 `_StatusStrip`；`test/status_parser_test.dart` 8 项、`test/home_status_strip_test.dart` 4 项 |
| `06f0724` | 更精细的成绩筛选（多学期复选） | ✅ | `GradeSemesterFilter.semesters`（Set）+ `toggleSemester` |
| `c02617c` | 快速置顶按钮 | ✅ | 成绩页 FAB「回到顶部」，`scrollController.animateTo(0)` |
| `0439699` | 异常成绩不参与均分、缓考特判 | ✅ | `gpaOf` 跳过非数字/零学分；缓考被解析为非数字 → 不计入 |
| `f331292` / `56c55d4` | 作业批改状态、批改后的成绩 | ✅ | `Homework.subStatus / score`，同步 diff 用它们判定变更 |
| `c6eecd8` | 作业附件下载 | ✅ | 作业详情「附件」区 + `downloadAttachment` |
| `c5418d2` (#32) | 修复作业上传接口 | ✅ | `homework_api.uploadFileRaw` + 详情弹层上传 |
| `9d8da18` | 成绩自选课程计算（面向全员） | ✅ | `GradeSelectionRecord`、`grade_controller` 自选与自算均分 |
| `13efd16` (#44) | 用缩写区分教学楼（请求仍用全名） | ✅（本轮补） | `ClassroomBuilding.abbreviation` + 列表徽章；`test/detection_page_test.dart` 5 项 |
| `758cc26` (#42) | 同步邮件已读状态、刷新未读提示 | ✅ | `EmailApi` 的 `mbox:updateMessageInfos`（标已读/未读/红旗）；首页状态条显示未读 |
| `4f6634b` (#45) | 底部菜单不能压到系统导航栏 | ✅ | `AppNavigation` 底部 `SafeArea` |
| `6c6f856` (#29) | 导出完整教学周课表为 .ics（**先确认首个教学周一**） | ⚠️ 本轮补上确认步 | `ScheduleIcs`（单次 VEVENT 展开、单双周、稳定 UID、行折叠、跳过计数）+ 新增 `_FirstWeekMondayDialog`；**保存位置**仍走应用下载目录，未接系统文档选择器 |
| `7318958` / `0546361` | 批量下载课件 | ✅ | 课件树整棵子树下载 |
| `d748702` | 教学日历下载（替代批量下载按钮） | ✅ | 「其他功能」页教学日历 |
| `3d98809` | DynamicColor 选项 | ✅ | `preferences.dynamicColorEnabled` + 主题 |
| `8943b7e` | 可选择是否检查更新 | ✅ | 设置「启动时检查更新」开关 |
| `2f02064` | 消息队列（网络请求顺序执行 / 并发控制） | ✅ | `DownloadService.maxConcurrent` + 队列；`RequestManager` 门闸 |
| `b57e3f2` | 切页面不重新加载数据 | ✅ | 控制器常驻 `ServiceLocator`（course/grade/exam/homework） |
| `676fb7b` | 桌面小组件改周视图 | ❌ | Dart 侧只留了契约（`CourseScheduleWidgetService.refresh` → `refreshHomeWidget` 平台通道），`android/` 下没有 AppWidget/Glance 实现，装上也不会有桌面小组件。需要原生实现才能真正交付 |
| `509157d` | 作业提醒订阅（填邮箱，第三方平台发信） | ❌ | 第三方服务，原项目自己注明「不保证稳定性」；Flutter 不做外部依赖 |
| `c0b41e1` | 悬浮导航栏、自定义壁纸、毛玻璃 | ⚠️ | 壁纸已做（首页封面，非全屏）；悬浮导航与毛玻璃不照搬，理由见下 |
| `164c2e0` / `f3d5421` | 整站改 Miuix 风格、靛蓝配色 | ⚠️ | 不复刻像素风格：本项目按 `docs/UI_SPEC.md` 做 Material 3 + 交大蓝，token 与可达性优先 |
| `ebd04b9` | 取消对作业提醒的支持 | — | 原项目已移除本地提醒，Flutter 同样没有 |

## 二、统计

- 已复现（有代码 + 测试）：**21 条**
- 部分复现（行为差异已登记）：**3 条**（ICS 保存方式、壁纸范围、Miuix 风格）
- 未移植（附理由）：**2 条**（桌面小组件、第三方订阅）
- 不适用：**1 条**（原项目已取消的功能）

## 三、差异说明

1. **ICS 保存位置**：原项目 `#29` 用系统文档选择器落盘；Flutter 走统一的 `DownloadService`
   （下载目录可在设置里改，也支持「每次都问」），跨端行为一致，代价是不能在导出那一刻挑目录。
2. **壁纸作用域**：原项目铺满全屏并把文字转白；本项目只做首页顶部封面 + 渐变回 `surface`。
   原因：`UI_SPEC` 第 2 节把对比度排在视觉偏好之前，全屏铺底要逐页重做对比度方案。
3. **不做 Miuix 风格复刻**：原项目最后一次大改是整站换 Miuix（含靛蓝配色、悬浮导航）。
   本项目有自己的设计规范与品牌色（交大蓝），复刻会与 `UI_SPEC` 的 token 体系冲突；
   功能对齐不受影响，只影响观感风格。

## 四、这次核对补的两处

| 补的东西 | 位置 | 为什么必须补 |
| --- | --- | --- |
| 教学楼缩写徽章 | `classroom_model.dart`（`abbreviation`）+ `detection_page.dart` | `#44` 是明确的用户可见改动；不补则列表只有图标，长楼名把副标题挤掉 |
| 导出前确认首个教学周一 | `course_schedule_page.dart`（`_FirstWeekMondayDialog`） | `#29` 的说明里明确要求「先确认第一个教学周一」；没有校历时锚点是推算的，错一周整张日历全错 |

## 五、复跑命令

```bash
flutter analyze
flutter test test/status_parser_test.dart test/home_status_strip_test.dart
flutter test test/detection_page_test.dart test/schedule_ics_test.dart
flutter test test/classroom_planner_test.dart test/classroom_page_build_test.dart
```
