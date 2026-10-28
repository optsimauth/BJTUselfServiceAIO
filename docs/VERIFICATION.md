# 本次验证记录

## 2026-10-25 UI 规范与美化复核

本轮结果、日志路径和未完成的渲染矩阵范围见 UI_CONSISTENCY_REVIEW.md。已通过独立导航/按钮 16 项、最终主题与 token 30 项、首页状态 5 项及手机四业务页分组 4 项；静态分析无问题。完整矩阵的中断批次不算通过。

## 前轮已通过（以下历史构建与全量测试未在本轮整体复跑）

- flutter analyze --no-pub：No issues found。
- 测试逐文件执行：43 个文件，**284 项通过 / 10 项按条件跳过**（无 BJTU_USERNAME / BJTU_PASSWORD、无 captcha.png 探针）。
- flutter build windows --debug --no-pub：生成 `build/windows/x64/runner/Debug/bjtuselfserviceaio.exe`。
- flutter build web --no-pub：生成 `build/web`。
- 设计审计脚本 `dart run docs/design-references/flutter-design/scripts/audit.dart lib/features/`：**20/20，零命中**（P3 间距也已统一到 token）。
- 真实公开 SSO 握手：应用原有 HttpClientFactory / Dio / CookieJar / RedirectFollower 到达学校 SSO，解析动态字段与 SM2 公钥；不提交凭据。
- SM2 互通：JavaScript sm-crypto 0.3.13 正确解密 Dart 生成的英文与中文合成密码密文。
- UI 矩阵：登录 / 首页 / 服务页在 360 / 820 / 1440 × 浅深 × 1.0 / 2.0 下无溢出；首页截图含实际状态条组件与注入的样例数值。
- 教室页：360 宽 2 倍字号无溢出；星期胶囊命中区 ≥ 48；窄屏格子只写节次号；规划面板「选节次 → 生成路线」交互通过。

## 本轮新增功能对应的验证

| 功能 | 测试 |
| --- | --- |
| MIS 状态接口（校园卡 / 校园网 / 未读邮件） | `test/status_parser_test.dart` 8 项：字符串 / 数字两种返回、部分字段、登录页 HTML 必须报错、空响应、余额阈值 |
| 首页状态条 | `test/home_status_strip_test.dart` 4 项：金额两位小数、未读「N 封」、未知不编数字、2 倍字号转竖排 |
| 空教室规划（楼层差最小） | `test/classroom_planner_test.dart` 8 项：楼层解析、单节、跨层最优、容量过滤、某节无空教室、空选择、去重排序 |
| 规划面板交互 | `test/classroom_page_build_test.dart`：点 FAB → 选节次 → 生成路线 |
| 自定义背景图 | 设置页写入偏好，首页 `StreamBuilder` 立即反映；路径失效或 Web 端自动不显示（无自动化截图） |
| 教学楼缩写徽章（原 #44） | `test/detection_page_test.dart` 5 项：11 栋固定缩写、其余取前两字、缩写不改全名、列表同时显示缩写与全名、2 倍字号不撑破 |
| 导出前确认首个教学周一（原 #29） | `test/schedule_ics_test.dart` 6 项覆盖事件生成；确认对话框为 UI 流程，人工看截图 |

## 修复：课件 / 作业打不开（课程平台的会话链）

现象：课件页「没拿到本学期课程」、作业页「作业刷新失败：没有课程」，两者都重试无效。

根因（对照旧项目 `SmartCurriculumPlatformRepository.initializeClient()`）：

1. 平台会话初始化**漏了第一步** —— 旧项目先访问 `mis.bjtu.edu.cn/module/module/28/`
   完成跳转、落下 MIS Cookie，再换 `sessionid`；Flutter 版直接去换 `sessionid`，
   平台按匿名单处理，课程清单返回空数组。
2. 握手失败被 `catch (_) {}` 吞掉，`headers()` 仍返回不含 `sessionid` 的头继续请求；
   两个仓库又把课程清单异常吞成空列表，最终界面只剩一句「没有课程」，真实原因丢失。

改动：

- `lib/data/remote/platform_session.dart`：先访问 MIS 模块入口再换 `sessionid`；
  拿不到就抛 `StateError` 并写日志（标签 `CoursePlatform`），不再静默降级。
- `lib/data/repositories/platform_course_repository.dart`：空清单/空学期号的报错带上学期号与原因。
- `lib/data/repositories/courseware_repository.dart`、`homework_repository.dart`：
  不再把课程清单异常吞成空列表，真实原因上到界面。
- 新增 `test/course_platform_session_test.dart` 7 项：入口→换会话的顺序、会话复用、
  `invalidate` 重握手、空 `sessionId`、返回登录页 HTML、入口失败、失败不缓存。

排查文档：`docs/TROUBLESHOOTING.md`。

## 测试怎么跑

```bash
flutter test                                          # 常规回归，不生成截图
flutter test test/classroom_planner_test.dart          # 单个文件
UI_REVIEW=1 flutter test test/ui_redesign_test.dart    # 登录 / 首页 / 服务页截图
flutter test tool/ui_shot_classroom.dart               # 教室页截图（浅/深）
```

截图输出统一在 `build/ui-review/`。

## 环境注意事项（不是代码问题）

1. **系统代理**：flutter_tester 用本地 WebSocket 与测试进程通信，`HTTP_PROXY` / `HTTPS_PROXY`
   指向本机代理时会报 `Invalid WebSocket upgrade request` 并卡死。跑测试时 `NO_PROXY=localhost,127.0.0.1` 或关掉代理。
2. **偶发进程退出**：本机同时加载全量中文字体 + 2 倍字号的重型 widget 用例（`ui_redesign_test`、
   `responsive_layout_test`）偶尔让 flutter_tester 直接退出，日志表现为若干用例 `did not complete`
   甚至 `No tests were found`。同一份代码换一次运行就会通过；`ui_redesign_test` 按
   `--plain-name phone|tablet|desktop` 分组跑稳定全过（4+4+4），两个交互用例单跑也过。
   遇到这种情况按环境问题处理：重跑该文件，不要改业务代码。

## 限制

- 功能对齐（按原项目 287 个提交逐条核对）见 `docs/FEATURE_PARITY.md`：21 条已复现、3 条部分、2 条未移植（桌面小组件、第三方订阅）。
- 没有真实账号，**新的状态接口没有做过真实请求验收**：只验证了协议形状（字段名与旧项目 `MisDataManager.getStatus`
  一致）、解析健壮性和界面表现。真实账号下若字段改名，界面会显示「未知」而不是错误数字（这是有意的降级）。
- 空教室规划用的是当前这一周、这一栋楼的课表数据；换楼/换周要先切好再规划。
- 自定义背景图只作用于首页顶部封面（对比度原因，见 ARCHITECTURE「与原 Compose 项目的功能对齐」）。
- 桌面小组件（Glance）与邮箱定时提醒未移植：前者需要 Android 原生实现，后者是 GitHub Actions 任务。
- Android 构建仍被 Gradle 分发包下载阻断，未产出 APK。
- iOS / macOS 无当前机器工具链，未做原生构建。

逐文件结果：`build/per-file-v2.txt`。构建日志：`build/windows-build-v4.txt`、`build/web-build-v4.txt`。
静态审计日志：`build/design-audit-features.txt`。

