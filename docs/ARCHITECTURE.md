# 架构说明与本次整理

## 判断

当前架构适合这个规模的校园工具：按功能组织页面，以 ChangeNotifier 管理视图状态，用 Repository 统一同步与本地缓存，通过 API / Parser 隔离学校接口。保留手写装配和现有状态管理，比引入另一套框架或给每个类增加接口更容易修改。

本次修复真实的职责与生命周期问题，没有按目录数量或设计模式数量做重构。

## 从启动到页面

main 初始化中文日期与日志 → ServiceLocator.bootstrap 创建依赖 → 从 Drift 恢复本地数据 → MaterialApp / go_router 展示页面 → AccountRepository 在后台恢复认证 → SyncCoordinator 等待认证结束后同步。

有本地凭据时可以先读缓存。认证失败显示重新登录入口，不删除缓存。明确退出才清理本地业务数据。

## 目录职责

- lib/app：程序装配、ServiceScope、go_router、应用主题和窗口导航外壳。唯一集中创建跨模块依赖的地方。
- lib/features/<功能>：Page、Controller、页面专用筛选/排版。Page 读状态、发出操作；Controller 负责筛选、选择、忙碌/错误等视图状态。
- lib/data/repositories：组织接口、缓存与同步。课程/成绩/考试/作业经过 LocalEntityStore 写 Drift；课件树存 SharedPreferences。
- lib/data/remote/api：描述请求与学校协议。认证握手在 AuthApi，邮箱协议在 EmailApi。
- lib/data/remote/parsers：HTML / JSON 的纯解析。SsoParser 校验表单来源、目标、OAuth 回调与加密配置。
- lib/data/models：课程、成绩、邮箱、课件等结构和可跨层复用的纯逻辑；不导入 features。
- lib/data/local：业务模型与 Drift 行之间的转换，采用显式类型读取 id，去除 dynamic 强转。
- lib/core：请求门闸、Cookie、重定向、异常、数据库、同步差异算法、存储与平台能力契约。
- lib/services：密码加密、下载、更新、文件选择、小组件等能力。
- lib/shared：主题 token、卡片、按钮、异步状态视图、日历等复用组件。

主要调用方向：Page → Controller → Repository → API / LocalStore → RequestManager / DAO。
数据模型供 UI 与数据层共同使用；app 负责组装它们，不要求每层都加一份接口。

## 新版 MIS 登录

1. GET https://mis.bjtu.edu.cn/auth/nsso/?next=/home/，记录最终页面 URI。
2. 若已经位于可信 MIS 首页且有身份标记，复用会话；否则解析 sso.bjtu.edu.cn 的 form#loginForm。
3. 保留 flowId、client_id、state、redirect_uri 等动态字段；严格校验 HTTPS、主机、端口、表单 action 和 MIS 回调。
4. 学校启用 SM2 时，用页面公钥加密 UTF-8 密码，编码为无 04 点前缀的 C1C3C2 Base64。
5. 用 application/x-www-form-urlencoded 提交到 /sso/login，逐跳保存和重新选择对应域名的 Cookie。
6. 最终地址必须是可信 MIS /home/ 且有身份标记，才算认证成功；之后建立课程平台、教务、本科生院会话。
7. 成功才保存凭据并发布 loggedIn。额外验证、协议变化和认证失败分别给出可操作的错误。

旧 CAS 验证码识别不再参与登录和启动依赖图。旧模型服务与测试保留为独立模块，没有继续通过修改旧表单字段来猜测新协议。

加密使用唯一新增的 gm_crypto 1.0.0。源码随机数使用 Random.secure；已用独立 JavaScript sm-crypto 0.3.13 解密英文、中文合成密码验证传输格式。不把私钥、真实账号或密码写入测试与仓库。

## 本次修复的结构问题

- 数据层反向导入 features：邮箱模型移入 data/models/email，邮箱解析移入 data/remote/parsers，课件树移入 data/models/courseware；修改全部调用方和测试。
- 成绩控制器固定启动学号：增加账号更新入口，由装配层监听登录状态更新。首次登录及退出/换号均更新自选成绩上下文。
- 退出后常驻缓存：销毁并重建邮箱和课件控制器，清理平台会话缓存。
- 登录/退出竞态：拒绝同时进行的两轮认证；退出等待进行中的认证收尾，以版本检查阻止迟到认证恢复凭据。
- 迟到业务响应：RequestManager 在请求完成时再次检查登录状态和会话版本，拒绝跨账号返回的数据。
- 认证安全：恢复系统 TLS 证书校验，认证链拒绝不可信/降级跳转，重定向调试日志不再记录查询中的 OAuth 票据。
- 组件与依赖装配混杂：LoginView、HomeDashboard、AppNavigation 可直接独立渲染和测试；入口仍通过 ServiceScope 取现有服务。
- 生命周期：应用释放 router，ServiceLocator 释放账户监听器、偏好流和网络客户端。

## 与原 Compose 项目的功能对齐

逐条核对（按原项目 287 个提交 / PR 说明）见 **`docs/FEATURE_PARITY.md`**。概要：

| 原项目功能 | Flutter 版 | 说明 |
| --- | --- | --- |
| 新版 MIS SSO 登录 + 本地 SM2 | 已实现 | `AuthApi` + `SsoParser`，逐跳 Cookie |
| 成绩（学期筛选/排序/均分） | 已实现 | 额外支持勾选课程自算 |
| 课程表（本科生院/研究生、单双周、导出） | 已实现 | 含 .ics 导出、教学日历 |
| 考试日程（变动提醒、已结束置灰） | 已实现 | 时间解析不出写「时间待定」 |
| 作业（筛选/排序/上传/下载） | 已实现 | 按课程 + 类型分片同步 |
| 课程资料（树形按需拉取） | 已实现 | 支持整棵子树批量下载 |
| 校内邮箱（收件箱/详情/快捷操作） | 已实现 | 另支持写信、待办、移动 |
| 首页状态：未读邮件 / 校园卡 / 校园网 | 已实现 | `osys_ajax_wrap`（`StatusApi` → `StatusParser`），三项收在一个指标条里 |
| 教室占用（整周格 + 此刻人数） | 已实现 | 教务表为主源，人数为副源 |
| 教学楼缩写标识 | 已实现 | `ClassroomBuilding.abbreviation`；请求与路由仍用全名（对应原项目 #44） |
| 空教室规划（楼层差最小路径） | 已实现 | 算法移植到 `classroom_planner.dart`，纯函数 + 单元测试 |
| 课表导出 .ics | 已实现 | `ScheduleIcs` 单次事件展开；导出前确认第 1 教学周周一（对应原项目 #29） |
| 校历 / 教学日历 / 成绩单下载 | 已实现 | — |
| 应用内更新 | 已实现 | GitHub Releases |
| 自定义背景图 | 已实现（有差异） | 原项目全屏铺底 + 白字；本项目按 `UI_SPEC` 只做首页封面，见下 |
| 桌面小组件（Glance） | 未移植 | 需要 Android 原生 Glance + 平台通道；多端项目里暂不做，避免只在一个平台可用 |
| 邮箱订阅 / 阈值邮件提醒 | 未移植 | 原项目靠 GitHub Actions 定时任务，不属于客户端功能 |

已知差异与理由：

- **背景图只作用于首页顶部**。原项目把图片铺满全屏、文字统一转白，这在浅色图和深色模式下都掉对比度；
  `UI_SPEC` 第 2 节把可访问性排在视觉偏好前面，所以改成首页封面 + 底部渐变回 `surface`，
  其余内容仍在实色上。要改回全屏铺底，需要先为每个页面准备对比度方案。
- **桌面小组件未移植**。Flutter 侧只能通过原生代码实现，且仅 Android 可用；
  跨端一致性优先，暂不引入单平台实现。

## 后续怎样改

新增学校接口：先在 API 定义请求，在 Parser 解析结构，在 Repository 组织缓存与同步，在 Controller 暴露视图状态，最后写 Page，并在 ServiceLocator 只装配一次。

修改样式：先改 shared/theme 或 DESIGN.md 中的语义 token，再改页面布局。不要在每个页面复制颜色、账号状态或 Dio 客户端。

新增同步模块：复用 SyncModule / SyncCoordinator / DataSyncManager。空远端结果默认不判全量删除，防止登录页或接口异常误删缓存；需要“确定为空”的业务流程时应显式验证协议，而非取消这个防护。

## 已知边界

- 当前原生平台能力仍依赖 dart:io、MethodChannel、文件目录与本机 Cookie。Web 编译结果不代表浏览器可以直接跨域登录学校；学校 CORS、浏览器 Cookie 和文件能力需要独立适配。没有为绕过浏览器限制引入代理服务器。
- iOS / macOS 需要对应 Apple 工具链；本机为 Windows，无法执行它们的原生构建与真机验证。
- 学校要求滑块、短信或其他二次验证时，本版明确提示需在学校网页完成验证，不尝试绕过。
- 使用浏览器 User-Agent 已读取真实学校 SSO 页面，并验证动态字段和当前公钥加密；未提交真实账号，因此协议与握手测试不能替代真实账号端到端登录验收。
- 课件、邮箱之外的多数业务 Controller 使用数据库流；详细业务页面保留现有实现。本次不是全仓按新状态框架改写。
