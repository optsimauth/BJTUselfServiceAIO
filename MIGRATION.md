# 迁移清单（bjtuselfservice → bjtuselfserviceaio）

从旧工程 `D:\Flutter\bjtuselfservice`（Android + 旧版 Flutter）逐个功能搬到本工程，
按「数据先对、界面再好看」的顺序做：一个功能搬完，它的 parser / repository /
domain / controller / page 和对应测试都得是绿的。

更新时间：2026-09-30

## 状态

| 功能 | 数据层 | 界面 | 测试 | 备注 |
| --- | --- | --- | --- | --- |
| 登录 / 首页 | ✅ | ✅ | ✅ | CAS 重定向链、按 host Cookie、验证码 |
| 课程表 | ✅ | ✅ | ✅ | 多数据源、周次、位置计算 |
| 考试 | ✅ | ✅ | ✅ | 分组、倒计时、已结束 |
| 作业 | ✅ | ✅ | ✅ | 筛选、详情弹层、附件 |
| 课件 | ✅ | ✅ | ✅ | 见下方「课件这一节的几个决定」 |
| 教室人数 | ✅ | ✅ | ✅ | 见下方「教室这一节的几个决定」 |
| 成绩 | ✅ | ✅ | ✅ | 见下方「成绩这一节的几个决定」 |
| 账户 / 设置 / 其他 | 旧实现 | ✅ | 部分 | 还没按分层重做 |

## 分层约定

```
lib/core            平台无关的基础设施：网络、存储、状态、Result/AsyncState
lib/data            模型、远端接口、解析器、仓库
lib/features/<名>    domain（纯计算，可单测）/ application（控制器）/ presentation（界面）
lib/shared          跨页面复用的组件与主题
test/support        假仓库 + 各页面测试脚手架
```

一条规矩：`domain` 只做纯计算，不碰网络也不碰 widget，所以每个判断都能单测；
`presentation` 通过构造函数注入 `*RepositoryPort`，测试里换成内存实现。

## 课件这一节的几个决定

- **数据模型**：`CoursewareNode`（扁平的 `id/name/kind/rpId/extension/…`）替换旧工程
  「四个可空字段 + when 取名字」的写法。`identity` 决定跨页稳定认路，课程/文件夹/文件
  分别加 `course-` / `bag-` / `res-` 前缀 —— 平台课程主键和 `resId` 都是小整数，不加前缀会撞。
- **逐层拉取**：资源树是 `up_id=0` 拿根，再用每个文件夹自己的 id 往下查一层，
  最多 6 层。不是一次性拿整棵树。
- **文件名**：HEAD 真正的 `rpUrl` 读 `Content-Disposition`（`filename*` 优先于 `filename`，
  去掉引号并做百分号解码），拿不到才回退平台自己的 `rpName`。
  旧代码的 `split(";")[1].trim().split("=").last()` 在 `attachment;filename=a.pdf`（没空格）、
  带引号的名字、以及 RFC 5987 的 `filename*=UTF-8''%E7%AC%AC...` 上都会解析错。
- **教学日历**：旧代码把 query 拼好之后去 GET 裸的 `coursePlatform.shtml`，参数全丢了。
  本工程把 query 正常传下去。
- **搜索**：命中文件名或所属课程名，大小写不敏感；命中**文件夹名**时列出该文件夹下所有
  文件（文件夹自己不当结果）；空搜索返回空列表而不是全部。
- **整包下载**：`CoursewareDownloadSummary` 逐个带回成功的 `identity`，半路失败时只把真下
  成功的标成已下，剩下几个留在「还剩 N 个」里。

## 教室这一节的几个决定

教室页的数据来自两个互不相干的源：第三方容量服务给「有几个人」，教务状态页给
「当天 7 节课哪节被占」。这一节的难处几乎全在「对不上」和「不知道」上。

- **分节状态只给颜色，不给文字**：`#fff` 是空闲，另外 5 个色值是各种占用。5 种占用
  之间的区别旧界面从来没写过文案，所以枚举里只有 `free` 写「空闲」，其余统一「占用中」，
  不编「已预约 / 考试中」这类说法。认不出来的色值落进 `unknown` 而不是被丢掉 ——
  旧代码在那里「什么都不加」，于是这间教室的状态列表比别的短一截，按节次去取就越界。
- **色值表按 6 位小写归一**：`#fff` 归一成 `#ffffff` 再查表。旧代码用字符串精确匹配
  `switch`，`#fff` 和 `#ffffff` 落在不同分支上，同一间教室的颜色被拆成两段长度不一的列表。
- **取色用正则而不是精确字符串**：`RegExp(r'background-color\s*:\s*([^;]+)')`，
  教务改一下空格就认不出的那种写法不算数了。行过滤也从旧代码的「跳过前两行」改成
  「教室名非空且至少认出一个颜色」—— 表头行数一变就错位的那种硬编码不能留。
- **两半的状态分开**：`state`（人数）和 `statusState`（分节）各有一份 `AsyncState`。
  分节挂了只是那七个点没了，列表照常出；反过来人数挂了页面才整个打成错误态。
  「清空筛选」只清关键词和「只看空闲」，排序偏好留着 —— 排序是用户选出来的口味。
- **「空闲」有两个口径**：`isFree`（还剩座位）用于「只看空闲」筛选和摘要计数，
  考试周找位子时半空的教室才是真能用的；`isEmpty`（一间人都没有）才让卡片写绿字
  「空闲」。半空的教室写「还剩 30 个座位」，写「空闲」会把人骗进坐了三十人的屋子。
- **人数读不出来就说读不出来**：`used >= capacity`（第三方服务在借用 / 未开放 /
  没数据时都这么报）时写「无法读取本教室人数」并且不画进度条，也不写「已用 60 / 60」。
  报一个「坐满了」等于把人引到一间进不去的教室去。所以顶上的那句话只有三态：
  空 / 还剩几个座位 / 读不出来。
- **教室名两边写法不一样**：容量服务有的给 `思源楼101`，状态页给光秃秃一个 `101`。
  `ClassroomWeekStatus` 先按整名查、再退到「结尾那段数字」，两边都能落到同一间。
  名表在 factory 里建一次，合并上百间教室不用每次重建 map。
- **详情不再开 WebView**：旧项目弹一个 WebView，POST 给第三方一个页面去渲染。本工程
  需要的分节占用上面那份数据里已经有了，直接画一张七行的单子（节次 + 作息 + 空闲/占用中，
  当前那节标「此刻」）。少一个依赖，也不用等一个网页加载。
- **筛选条用 `Wrap` 不用 `Row`**：四颗 chip 加两颗按钮在 360dp 机型上放不下会溢出，
  换行比横向滚动好 —— 每颗 chip 都还在，不用先划一下才够得着。

## 成绩这一节的几个决定

成绩页的数据是 aa 教务成绩页那张表格，旧代码在 `MisDataManager.getGrade` 里直接抠 HTML。
这一节的坑全在「成绩格式怎么归一」和「勾选身份用什么当主键」上。

- **成绩存成 `等级,分数`**：`A,95` / `B,83`。端口 `Utils.convertAndGradeFormatScore`，
  加了幂等保护 —— 已经是「等级,数字」形状的不再二次换算。读不出来就是 `-,-`。
  注意中文等级字（优秀 / 及格）**不在**旧代码的等级表里，`convertAndGradeFormatScore`
  对它们直接返回 `-,-`（`-,-` 表示没出分，界面上不能拿它算加权、也不显示成 0 分），
  本工程和旧代码保持一致，不为它编分数。
- **两套换算表从旧代码原样搬来**：等级→分数 `A:95 … F:30`；分数→等级用阈值
  `90/85/81/78/75/71/68/65/61/60`。两条路都只认数字：`93` → `A,93`，`83` → `B,83`。
- **表格列按位置取**：`0 序号(跳过) / 1 学年学期→courseYear+tag / 2 课程名称 /
  3 学分(空→`0.0`) / 4 成绩 / 5 绩点(跳过) / 6 任课教师 / 7 备注`。备注藏在
  `span[data-content]` 里，还要再剖一层 `div[style*=200px]` 才是正文，`<br>` 换成换行。
  表头（`th`）和「合计」这类页脚行靠形状跳过：课程名为空、或学年学期为空的行都直接
  不算成绩。
- **合并去重按 `课程名|成绩|学分`**：同一门课重了只留一条。
- **勾选的身份 = `课程名\u0000教师\u0000学年学期\u0000学期tag`** 拼的复合键，不是学生号
  + 课程号那套 —— 成绩表里没有稳定主键。所以勾选只存内存 + 本地持久化，sync 后把
  「成绩表里已经不存在」的勾选记录清掉。
- **GPA 口径**：普通模式按筛选后的全量算，自选模式只算勾选的那几门；「全选」只选
  当前筛选结果。GPA 卡显示「统计 N 门」+ 评语（按 92.5/87.5/82.5/70/60 分档），
  一门都不认识时显示长横而不是 0。
- **分数颜色按数值**：`<60` 红，`60–100` 红到绿渐变，没出分灰色 —— 旧代码把 `<60`
  那档写进了绿色分支，越考得低颜色越绿，这是修掉的旧 bug。
- **未知分数的课排到最底下**：排序时没出分的沉底，不让「还没出分」插进分数中间。
- **空 tag 的学期显示「未标注学期」**：学期筛选的选项、GPA 卡的年学期标签都这么标，
  不装成某个真实学期。
- **成绩单下载是本工程新加的**：旧项目没有这个功能。中英文两个 PDF 端点
  （`type=card_cn_sign` / `card_en_sign`），下载失败直接抛，页面弹错误。

## 错误文案

所有「讲给人听」的地方都写 `StateError('中文话')`。`StateError.toString()` 前面挂着
「Bad state: 」这个给开发者看的前缀，原来错误页和错误弹窗都是 `'$error'`，
于是界面上写着「Bad state: 没能查到当前学期」。`shared/widgets/error_text.dart`
的 `errorText()` 把它拆掉只留那句话；其余错误原样透出（接口的 404、超时虽然不好看，
但比笼统的「出错了」多些线索）。`AsyncView` 和 `AppDialog.error` 都走它。

## 返回按钮（跨页面）

桌面 / 网页端没有系统返回键，进到子页面后得给一个看得见的出口：

- 进子页面一律用 `context.push`（原来是 `context.go`）。`go` 把 go_router 的栈整个
  换掉，`Navigator.canPop` 变 false，AppBar 连自动返回箭头都不出现 —— 进去了
  出不来。`push` 让子页面压在上层，pop 回到原来的 tab。
- 每个子页面（课程表 / 成绩 / 考试 / 作业 / 课件 / 空教室 / 教室详情 / 我的 /
  邮箱 / 其他功能）的 AppBar `leading` 都挂 `PageBackButton`（`lib/shared/widgets/
  buttons/app_buttons.dart`）。它包一层 `BackButton` + `Tooltip('返回')`，走
  `Navigator.maybePop`：能退就退，已经是第一页（深链直达）就什么都不做。
- 登录后的 `go('/home')` 这类整栈复位保持 `go` 不动。

## 真实接口测试（test/network_test.dart）

这一份和其余测试不是一类东西：它**不打任何 mock**，只干一件事 —— 逐个打学校真的接口，
把返回内容打印 + 落盘，好确认哪个接口还活着、返回的是真数据还是登录页。16 个用例覆盖
SSO/学生信息、成绩（ln/lr/PDF）、考试、课表（当前+历史）、教室状态与容量、校历、
课程平台（教学周/学期/课程清单/sessionid）、作业、课件、教学日历、GitHub 版本检查。

- **默认整份跳过**：`BJTU_NETWORK_TEST != 1` 时 16 个用例全是 `Skip`，全量
  `flutter test` 不会去动学校服务器，验收流程不受影响。
- 登录走 CAS 真实流程。测试环境没有原生验证码识别（那是 `windows/runner` 里的 onnx，
  走 MethodChannel），所以改成人工：验证码图片写到
  `build/network_test/captcha-1.png`，把算式答案写进
  `build/network_test/captcha_answer.txt`，登录最多等 3 分钟。
- 每个探针的完整响应写到 `build/network_test/NN-名字.txt`（UTF-8）。终端只打摘要和
  前 400 字符 —— PowerShell 控制台编码不稳，全量贴出来多半是乱码。
- 「返回的是 CAS 登录页」被当成失败报出来（`looksLikeLoginPage`）。登录态掉了的时候
  学校不给 401 而是把登录页原样甩回来，这正是「成绩加载不出来」最常见的成因，
  必须一眼认出来而不是当成「接口返回了空表」。
- 客户端刻意不走 `ServiceLocator`：那会把数据库、secure storage、平台插件一起拉进来，
  而这里只需要「一个会带 cookie 的 dio」。
- 登录挂在一个 memo 化的 Future 上而不是 `setUpAll` —— `setUpAll` 没有自己的 timeout
  参数，只能吃 `dart_test.yaml` 的 90s，而登录要等人手填验证码。

```powershell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8   # 否则中文全是乱码
$env:BJTU_NETWORK_TEST = '1'
$env:BJTU_STUDENT_ID  = '学号'
$env:BJTU_PASSWORD   = '密码'
flutter test test/network_test.dart
```

## 测试规模

一共 762 个用例（51 个文件；其中 `network_test.dart` 的 16 个默认跳过）。这台机器
16 核、可用内存常常只剩 3 GB：

- 必须显式 `flutter test --concurrency=1`（`dart_test.yaml` 里的 `concurrency` 会被忽略）。
- widget 用例按主题拆文件（每个文件 ≤16 个 `testWidgets`），装配代码放
  `test/support/*_harness.dart`。
- 内存压力会掐掉 isolate，两种表现：跑到尾部几个用例变成 `did not complete`（没有异常），
  或者某个文件直接 `Failed to load ... Connection closed before test suite loaded`。
  都跟代码无关 —— 单独重跑那个文件就是绿的。
- 一轮全量跑到 570~600 个用例左右必被掐，所以验收分两步：先全量跑一遍，
  再把被掐掉的文件单独跑一遍。分成两半跑（各 25 个文件）也盖不住全部，
  被掐掉的那几个文件再单独补跑。

## 验收命令

```powershell
flutter analyze --no-fatal-infos
flutter test --concurrency=1
# 被掐掉的文件单独补跑，例如：
flutter test --concurrency=1 test/classroom_page_filter_test.dart test/homework_page_list_test.dart
# 真实接口另跑（默认跳过，不带环境变量就是全 Skip）：
flutter test test/network_test.dart
```

## 边界

打勾只表示代码路径、界面和测试都在，不代表真实账号下每个校园接口都已在线验证。
要在线验证就用 `test/network_test.dart`（见上面「真实接口测试」）。
