# 本地缓存与网络刷新任务书

> 状态：Plan 阶段
>
> 范围：作业、成绩、课表、考试
>
> 目标：每次加载先展示 Drift 本地数据，同时发起网络请求；网络成功后落库并展示明确的变化消息。
>
> 参考：<https://drift.simonbinder.eu/>

## 1. 需求定义

### 1.1 用户流程

1. 用户进入首页或四类业务页面。
2. 页面立即订阅本地 Drift 数据；有缓存就先展示缓存，没有缓存才显示空加载态。
3. 页面同时发起网络刷新，不阻塞本地数据展示。
4. 网络数据解析成功后，与同步前的本地快照比较。
5. 把新增、修改、删除写入 Drift。
6. 页面通过 Drift stream 自动刷新，并展示变化消息。
7. 网络失败时保留旧本地数据，显示“刷新失败/正在使用上次数据”，不能清空页面。

### 1.2 四类数据

| 模块 | 本地表 | Repository | 当前同步入口 |
| --- | --- | --- | --- |
| 课表 | `CourseTable` | `CourseRepository` | `sync()` |
| 成绩 | `GradeTable` | `GradeRepository` | `sync()` |
| 考试 | `ExamTable` | `ExamRepository` | `sync()` |
| 作业 | `HomeworkTable` | `HomeworkRepository` | `sync()` |

### 1.3 明确不做

- 不新增 Hive、SharedPreferences JSON 或第二套 SQLite 缓存。
- 不改网络 API、HTML/JSON 解析协议。
- 不做系统推送、通知中心、后台定时任务。
- 不把每一次网络请求都提示成“有更新”。
- 不在本任务中改空教室、课件、个人资料的缓存策略。

## 2. 现状与复用点

项目已经具备实现所需的主要结构：

- `lib/core/database/database.dart` 已定义四张 Drift 表，schemaVersion 当前为 2。
- `lib/data/local/local_stores.dart` 已把 Drift DAO 适配成 `LocalEntityStore<T>`。
- 四个 Repository 已提供 `watchAll()` 与 `sync()`。
- `lib/core/state/data_sync_manager.dart` 已提供新增、修改、删除检测和落库。
- `SyncCoordinator` 已统一编排四个模块的同步。
- `HomeController`、`CourseController`、`GradeController`、`ExamController`、`HomeworkController` 已订阅本地 stream。

因此最小方案是：补强同步结果和页面状态，不重做数据层。

## 3. 目标架构

```text
页面 Controller
    ├─ 订阅 Repository.watchAll()
    │    └─ Drift stream -> 先显示本地数据
    └─ 触发 Repository.sync()
         ├─ 请求网络
         ├─ 解析远端模型
         ├─ 保存同步前本地快照
         ├─ DataSyncManager.detectChanges()
         ├─ Drift transaction 写入变化
         └─ 返回 SyncResult
              └─ Controller/页面显示变化消息
```

### 3.1 两条路径必须分离

**展示路径**：`Drift -> watchAll() -> Controller -> UI`

- 不等待网络。
- 网络失败不影响已经展示的数据。
- 首次安装无本地数据时才显示空态。

**刷新路径**：`UI -> Controller.refresh/syncAll -> Repository.sync -> Drift`

- 请求、解析、比较、落库按顺序完成。
- 只在远端数据完整可用时处理删除。
- 发生异常时返回失败结果或抛出异常，但不能清空旧数据。

## 4. 统一同步结果

新增一个轻量结果模型，建议放在：

`lib/core/state/sync_result.dart`

建议字段：

```dart
class SyncResult {
  const SyncResult({
    required this.module,
    required this.added,
    required this.modified,
    required this.deleted,
    required this.completedAt,
  });

  final SyncModule module;
  final int added;
  final int modified;
  final int deleted;
  final DateTime completedAt;

  bool get hasChanges => added + modified + deleted > 0;
  int get totalChanges => added + modified + deleted;
}
```

注意：实现时不要把 `SyncResult` 与 `SyncModule` 产生循环依赖。更简单的做法是把模块名定义在结果文件，或让结果只保存 `String label`。

建议所有四个 Repository 的 `sync()` 统一返回 `Future<SyncResult>`。这是本次改动的公共契约。

## 5. 变更检测规则

### 5.1 统一消息文案

按变化数量生成一条消息：

- 新增且无修改/删除：`已更新：新增 N 条`
- 修改且无新增/删除：`已更新：N 条发生变化`
- 删除且无新增/修改：`已更新：删除 N 条`
- 多种变化：`已更新：新增 A 条，变化 B 条，删除 C 条`
- 没有变化：不弹 SnackBar；只更新“已刷新”时间或保持安静。

模块名由页面上下文提供：作业、成绩、课表、考试。

### 5.2 各模块 identity 与变更字段

沿用现有 Repository 的 identity 和 `changed` 判断，不另写第二套比较逻辑：

- **课表**：以现有 `Course.identity` 判定同一课程/课格；比较课程名、教师、时间、地点等现有字段。
- **成绩**：以现有 `Grade.identity` 判定同一成绩；比较成绩、学分、教师、标签、详情。
- **考试**：以现有 `ExamSchedule.identity` 判定同一考试；比较时间地点、状态、详情。
- **作业**：以现有 `Homework.identity` 判定同一作业；比较成绩、提交状态、作业状态、提交标识、截止时间、标题。

如果执行阶段发现 identity 不含业务唯一字段，先补 identity 测试和最小修正，再改同步逻辑。禁止只按数据库自增 id 比较远端数据。

### 5.3 删除安全规则

这是实现时的重点：

- 只有在该模块的远端数据被确认“完整”时，才允许把本地有、远端没有的数据判定为删除。
- 单门课、单类型、单学期请求失败时，不能把该局部失败误判为全局删除。
- 作业按课程和类型分批请求；只要存在失败分片，就不要对对应不完整范围执行删除。
- 课表按当前/历史学期请求；某个学期失败时，不删除该学期本地记录。
- 成绩两个来源至少成功一个才同步；来源部分失败时，保守保留本地无法确认的记录。
- 考试页面整体请求失败时，不改本地数据。

实现优先选择“同步范围完成标记 + 只对完成范围删除”，不要为了省几行代码清空后全量插入。

## 6. 页面生命周期方案

### 6.1 首页

当前 `HomePage.initState()` 已执行“先 `refresh()`，再 `syncAll()`”。执行阶段调整为：

1. `HomeController` 构造时订阅三类本地 stream。
2. `refresh()` 只负责从本地组合首页摘要，不把 state 置成会隐藏缓存的空 loading。
3. `syncAll()` 后台执行四模块同步。
4. 汇总所有 `SyncResult`，只对有变化的模块展示一条合并消息。
5. 首页已有内容时，网络请求期间保持内容可见，只显示同步指示器。

首页涉及课表、作业、考试；成绩不在首页摘要，但全量同步仍按设置开关执行。

### 6.2 四类详情页

每个 Controller 构造后已经有 `watchAll()` 订阅，执行阶段只需统一状态语义：

- 首次收到本地 stream：直接写入 `_courses`、`_grades`、`_exams`、`_homework`，设置 data 状态。
- `refresh()` 不先把已有数据替换成 loading；用 `isRefreshing` 或现有同步状态表示后台刷新。
- 同步成功后由 stream 推送最新数据；Controller 读取 `SyncResult` 生成消息。
- 同步失败时保留 data 状态，同时展示失败提示；只有“本地为空且网络失败”才进入错误空态。

### 6.3 页面消息职责

建议不要让 Repository 直接操作 SnackBar。Repository 只返回结果；页面 Controller 暴露最近一次 `SyncResult` 或一次性消息事件，页面负责展示。

最小实现可以使用：

```dart
final ValueNotifier<String?> syncMessage = ValueNotifier(null);
```

消息消费后置空，避免页面重建重复弹出。若现有架构已有全局消息通道，优先复用，不新建事件总线。

## 7. 实施分解

### Phase 1：同步结果与纯逻辑

文件候选：

- `lib/core/state/sync_result.dart`
- `lib/core/state/data_sync_manager.dart`
- `lib/data/repositories/course_repository.dart`
- `lib/data/repositories/grade_repository.dart`
- `lib/data/repositories/exam_repository.dart`
- `lib/data/repositories/homework_repository.dart`

工作：

1. 把 `DataSyncManager.apply()` 改为返回统计结果，或新增一个不破坏现有调用者的统计方法。
2. 四个 `sync()` 返回统一 `SyncResult`。
3. 保证“网络失败不落库、不删除、不覆盖旧数据”。
4. 修正分片同步的删除边界。
5. 为变更消息格式写纯函数。

交付检查：

- 新增/修改/删除统计准确。
- 空变化不产生消息。
- 任意请求失败后旧数据仍在。

### Phase 2：Controller 加载状态

文件候选：

- `lib/features/home/home_controller.dart`
- `lib/features/course/course_controller.dart`
- `lib/features/grade/grade_controller.dart`
- `lib/features/exam/exam_controller.dart`
- `lib/features/homework/homework_controller.dart`

工作：

1. 把“本地已有数据”和“网络刷新中”拆成两个状态维度。
2. 保证 refresh 期间列表不闪空。
3. 将 Repository 的 `SyncResult` 传到页面消息层。
4. 防止同一模块并发刷新重复请求；沿用现有 ponytail 备注，若本任务触发实际重复则补最小 in-flight guard。
5. Controller dispose 后不再写状态或弹消息。

交付检查：

- 有缓存：页面首帧能展示缓存，网络请求不阻塞。
- 无缓存：显示正常空加载态。
- 网络失败：缓存仍可读，并有可理解的失败提示。

### Phase 3：页面消息与首页串联

文件候选：

- 四类页面对应的 `*_page.dart`
- `lib/features/home/home_page.dart`
- 必要时 `lib/data/repositories/sync_coordinator.dart`

工作：

1. 详情页在手动刷新完成后显示变化消息。
2. 首页全量同步把多个模块的变化合并成一条消息，避免连续弹四次。
3. 自动同步不应每次无变化都打扰用户。
4. 保留右上角刷新和下拉刷新入口。

交付检查：

- 新增作业、成绩更新、课表变化、考试地点变化均可看到对应提示。
- 无变化刷新不弹“有更新”。
- 首页全量同步最多一条合并消息。

### Phase 4：测试、生成代码与静态检查

工作：

1. 为同步统计、变化消息、分片失败保护补输入输出测试。
2. 为四个 Repository 的“本地快照 + 网络结果”路径补测试；优先 fake API/fake store，不启动真实登录。
3. 运行 Drift/build_runner（只有表结构变化时才生成新代码；本任务原则上不改表）。
4. 运行 `flutter analyze`。
5. 运行定向测试，再运行完整测试。
6. 手动行为探针：有缓存启动、无网络刷新、远端新增/修改/删除、分片失败。

## 8. 测试清单

### 必须覆盖

- `detectChanges`：新增、修改、删除、无变化。
- 变化消息：单一变化、多种变化、零变化。
- 网络异常：本地数据不被清空。
- 课表单学期失败：另一学期成功，本地失败学期保留。
- 作业单课程/单类型失败：不误删未确认范围。
- 页面已有缓存时 refresh：状态不闪到空列表。
- Controller dispose 后异步完成：不抛异常、不通知页面。

### 直接行为探针

```text
场景 A：数据库已有 3 条作业 -> 打开页面
期望：先显示 3 条，同时出现刷新指示器。

场景 B：网络返回 1 新增、1 修改、0 删除
期望：列表更新，出现“新增 1 条，变化 1 条”。

场景 C：网络超时
期望：旧列表保留，提示刷新失败，不出现“删除全部”。

场景 D：作业只成功拉到部分课程
期望：成功范围更新，失败课程的旧记录保留。
```

## 9. 验收标准

### 功能验收

- [ ] 作业、成绩、课表、考试四页均先显示本地数据。
- [ ] 本地读取不等待网络请求完成。
- [ ] 页面加载期间会发起网络刷新。
- [ ] 网络成功后数据自动更新。
- [ ] 新增、修改、删除能显示准确消息。
- [ ] 无变化时不显示虚假更新消息。
- [ ] 网络失败时旧数据不丢失。
- [ ] 分片请求失败不会误删未确认范围。
- [ ] 登出仍清空业务缓存。

### 工程验收

- [ ] 不新增缓存依赖。
- [ ] 不新增第二套数据模型或重复比较逻辑。
- [ ] 现有 Drift schema 无不必要升级。
- [ ] `flutter analyze` 通过。
- [ ] 定向测试通过。
- [ ] 关键行为探针通过。

## 10. 执行顺序

按以下顺序实施，不跨阶段堆改动：

1. 先改 `DataSyncManager` 和 `SyncResult`，补纯逻辑测试。
2. 再改四个 Repository，确保同步结果准确且删除安全。
3. 再改五个 Controller，保证本地优先和刷新状态。
4. 最后接页面消息、首页合并消息。
5. 每一阶段运行对应测试；失败时只修当前阶段，不直接扩大范围。

## 11. 实施前需要确认的一个产品选择

本任务书默认采用：

> “变化消息”使用页面内 SnackBar；无变化不提示；网络失败使用保留数据的错误提示。

如果需要系统通知、消息历史、点击消息定位到具体记录，需要另开任务，不放进本次最小实现。
