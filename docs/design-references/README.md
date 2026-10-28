# 下载的 UI 设计参考

设计参考分为可运行的 UI 组件项目与设计规则。完整源码在本机保存，仓库内只保留许可证与便于追溯的样式参考。它们不是运行时依赖，不会进入应用安装包。

## 主视觉参考：Flutter Shadcn UI

- 来源：https://github.com/nank1ro/flutter-shadcn-ui
- 固定版本：`4fe5440765d4faf1855f3a2c456052b4121b3424`。
- 完整下载：`build/design-references/flutter-shadcn-ui/`。
- 风格：Slate 中性色、细边框、小圆角、清晰的操作层次；结合本项目的交大蓝与中文字体。
- [具体内容、下载位置与适配说明](flutter-shadcn-ui/README.md)。
- 原有 Flutter Design Skill 与 UI UX Pro Max 继续作为响应式和可访问性规则依据。

## Flutter 专用 AI 设计技能

- 来源：https://github.com/priyeshchowta/flutter-design-skill
- 下载版本：7cb5cd35bfa241866ca8e3e5643a5929530358cd
- 完整下载：%TEMP%/bjtu-flutter-design/
- 仓库内保留：flutter-design/SKILL.md、reference/、data/、scripts/ 和原 MIT LICENSE。
- 本次采用：先读产品与用户场景，定义 token，避免重复卡片宫格，手机底栏 / 平板侧栏，支持 2 倍字号，实际渲染后复查。
- 本地审计：dart run docs/design-references/flutter-design/scripts/audit.dart lib/features/
- 审计结果是启发式线索，不是可访问性认证。对 core/platform 的 Platform.isX 告警不适用：平台适配层本来就负责选择原生实现。

## UI UX Pro Max

- 来源：https://github.com/nextlevelbuilder/ui-ux-pro-max-skill
- 下载版本：d14efff8ed1faa4187f004f79926f428c8074ec7
- 完整下载：%TEMP%/bjtu-ui-ux-pro-max/
- 仓库内保留：ui-ux-pro-max/flutter.csv 和原 MIT LICENSE。
- 本次采用：LayoutBuilder、TextScaler、持续可见的输入标签、操作反馈和浅深色检查。
- 未采用检索结果中的产品营销落地页与英文字体方案：不符合中文校园工具用途。

## 应用方式

适用优先级为：Flutter 官方响应式/无障碍说明 → 已下载参考中的质量底线与规则 → 本项目的视觉选择。docs/UI_SPEC.md 标明出处与区别；根目录 DESIGN.md 记录产品方向，docs/DESIGN_SYSTEM.md 记录 token。原始规则保留原文，审计脚本只作启发式检查，不代替渲染、交互与无障碍验证。

原 Android 项目此次登录修复的主要协议依据：
https://github.com/HFDLYS/BJTUselfService/commit/5f875d5ee22ef079be8ba17028397e3f4f4fd854

