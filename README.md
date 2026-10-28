<div align="center">

# 🚄 交大自由行 AIO

> 北京交通大学校园服务 · Flutter 多端重写版

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.13-0175C2?style=flat-square&logo=dart)](https://dart.dev)
[![License](https://img.shields.io/github/license/optsimauth/BJTUselfServiceAIO?style=flat-square)](LICENSE)
[![Stars](https://img.shields.io/github/stars/optsimauth/BJTUselfServiceAIO?style=flat-square&label=Star)](https://github.com/optsimauth/BJTUselfServiceAIO)
[![Forks](https://img.shields.io/github/forks/optsimauth/BJTUselfServiceAIO?style=flat-square&label=Fork)](https://github.com/optsimauth/BJTUselfServiceAIO)

**原项目**：[HFDLYS/BJTUselfService](https://github.com/HFDLYS/BJTUselfService)（Android / Kotlin）

</div>

## 📖 这是什么

[交大自由行](https://github.com/HFDLYS/BJTUselfService) 是一款专为北京交通大学师生打造的校园服务应用。它通过自动登录 MIS 系统，把成绩查询、课程表、考试安排、作业管理、邮件查看这些每天都要用的功能，整合进一个界面。

数据解析与登录密码加密在**本地完成**，不经过第三方代理服务器。

**AIO 是它的 Flutter 多端重写版** —— 同一套功能，一个代码库，同时跑 Android / iOS / macOS / Windows / Web。

平台验证与限制请看 [架构说明](docs/ARCHITECTURE.md#已知边界)：Web 编译通过仍需浏览器跨域、Cookie 与文件能力适配，不能等同于原生端完整可用。

## ✨ 功能特性

### 🔐 智能登录
- 适配新版 SSO，自动建立 MIS / 教务 / 课程平台会话
- **本地 SM2 加密**密码，动态读取 OAuth 表单参数
- 学校要求额外验证时给出明确提示
- 登录状态持久化，打开即用
- 账号密码存系统安全存储（Keychain / Keystore）

### 📚 学业管理
- **成绩查询** — 按学期筛选、排序，等第与数字分都认，自动算均分
- **课程表** — 网格课表，支持学期切换、单双周、第几周定位
- **考试日程** — 自由文本拆成日期 / 时段 / 地点，**解析不出就写「时间待定」，绝不瞎猜倒计时**
- **作业管理** — 按课程 + 类型分片同步，筛选排序、附件下载、作业上传
- **课程资料** — 资源树按需逐层拉取，支持整棵子树批量下载

### 📨 信息服务
- **校内邮箱** — 免登录查看邮件
- **首页状态条** — 未读邮件 / 校园卡余额 / 校园网余额（MIS 状态接口，余额不足与断网会提示）
- **教室状态** — 实时查看教室人数与整周占用
- **空教室规划** — 选几个节次，按「楼层变动最小」给出自习路线（动态规划）

### 📅 日历与提醒
- 日历视图整合作业截止与考试时间
- 「本次同步发现了 N 条变化」——检测到成绩 / 考试 / 作业变动时先给你看，确认后才落库

### 🏫 校园工具
- 校历 / 教学日历 / 成绩单下载（中英文）
- 应用内更新（GitHub Releases）
- 自定义主题、动态取色、深色模式
- 自定义背景图（设置 → 外观，首页顶部封面）
- **项目 Star 变化页** —— 记录并展示仓库星数趋势

## 🏗️ 技术架构

```
┌──────────────────────────────────────────────┐
│                  UI 层                       │
│        Flutter Widgets + Material 3           │
│  Page → Controller（ChangeNotifier）          │
├──────────────────────────────────────────────┤
│                逻辑 / 同步层                  │
│  SyncCoordinator（登录后后台同步 + 变化提示）   │
│  DataSyncManager（新增 / 变更 / 删除 diff）    │
├──────────────────────────────────────────────┤
│                 数据层                       │
│  Repository → Dao → Drift(SQLite)            │
│  Dio + CookieJar（会话） + html 包（解析）    │
│  SharedPreferences / SecureStorage           │
├──────────────────────────────────────────────┤
│                 AI 模块                       │
│      onnxruntime（验证码本地识别）             │
└──────────────────────────────────────────────┘
```

### 主要依赖

| 类别 | 技术 |
|------|------|
| UI 框架 | Flutter + Material 3 |
| 路由 | go_router |
| 状态管理 | ChangeNotifier（无第三方） |
| 网络请求 | Dio + CookieJar |
| HTML 解析 | `html` |
| 本地数据库 | Drift（SQLite） |
| 本地存储 | shared_preferences + flutter_secure_storage |
| AI 推理 | onnxruntime |
| 桌面 WebView | webview_all |

> **零代码生成**：除了 Drift 的 `build_runner`，没有别的 codegen。
> 依赖注入是手写的 `ServiceLocator`，没有 get_it，没有 Hilt。

完整目录职责、认证流程、本次架构修复与平台边界见 [架构说明](docs/ARCHITECTURE.md)。
界面采用「Slate 中性色 + 交大蓝」，主视觉参考为已下载的 [Flutter Shadcn UI](docs/design-references/flutter-shadcn-ui/README.md)。设计方向见 [DESIGN.md](DESIGN.md)，规则与来源见 [参考说明](docs/design-references/README.md)。

## 🚀 快速开始

### 环境要求

- Flutter 3.x（Dart SDK ^3.13）
- Android：compileSdk 34+，设备 API 28+
- iOS / macOS：Xcode 15+
- Windows：Visual Studio 2022 + C++ 桌面开发
- Web：Chrome

### 构建步骤

```bash
git clone https://github.com/optsimauth/BJTUselfServiceAIO.git
cd BJTUselfServiceAIO

flutter pub get

# Android
flutter build apk --release
# iOS
flutter build ipa
# Windows
flutter build windows --release
# macOS
flutter build macos --release
# Web
flutter build web
```

开发时直接 `flutter run` 即可。

## 🔒 隐私与安全

- ✅ 密码按学校新版协议在本地做 SM2 加密；使用系统 TLS 证书校验
- ✅ 账号密码只存本机安全存储，不上传
- ✅ 课程 / 成绩 / 作业等数据全部落在本地数据库，只在需要时向学校系统发请求
- ✅ GitHub Star 页只读取公开仓库元信息，不带任何用户凭据


## 🤝 贡献

欢迎提 issue 和 PR。改动前先跑：

```bash
flutter analyze
flutter test
```

界面截图不参与断言，默认不生成；需要看图时：

```bash
UI_REVIEW=1 flutter test test/ui_redesign_test.dart   # 输出到 build/ui-review/
```

## 📄 致谢

本项目是 [BJTUselfService](https://github.com/HFDLYS/BJTUselfService) 的重写版，感谢原作者和各位贡献者：

- [HFDLYS](https://github.com/HFDLYS) 及原项目全体贡献者 —— 最初的 Android 版本
- [optsimauth](https://github.com/optsimauth) —— 架构重构与本次 Flutter 重写
- [guh0613](https://github.com/guh0613) —— 自动构建与发布
- [carolyn-sun](https://github.com/carolyn-sun) —— 工作流配置
- [NAPHthalene130](https://github.com/NAPHthalene130) —— bug 修复
- [B-Silva20](https://github.com/B-Silva20) —— 成绩自选课程计算
- [wangxiaobo1747](https://github.com/wangxiaobo1747) —— 自定义壁纸与桌面组件

## 📄 License

[MIT](LICENSE)
