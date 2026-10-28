# 故障排查

## 课件 / 作业打不开（页面只显示「没有课程」）

这类页面的数据都来自**智慧教学平台**（`http://123.121.147.7:88`），而平台不认 MIS 的登录态，
必须先换到平台自己的 `sessionid`。整条链是：

1. `GET https://mis.bjtu.edu.cn/module/module/28/` —— 走 MIS 的课程平台模块入口，
   完成跳转并落下 MIS Cookie（**这一步不能省**，平台按它认人）。
2. `GET …/coursePlatform/message.shtml?method=getArticleList` —— 换 `sessionId`。
3. `GET …/rp/common/teachCalendar.shtml?method=queryCurrentXq` —— 当前学期号 `xqCode`。
4. `GET …/coursePlatform/course.shtml?method=getCourseList&…&xqCode=…` —— 本学期课程清单。
5. 之后才是按课程查作业（`homeWork.shtml`）和课件（`courseResource.shtml`），
   每个请求都要带 `sessionid` 头。

历史上第 1 步漏了、并且握手失败被静默吞掉，于是第 4 步拿到空数组，
界面只剩一句「没有课程」—— 现在第 1 步已补上，失败也会直接说明原因。

### 看到这些提示时怎么处理

| 提示 | 含义 | 处理 |
| --- | --- | --- |
| 课程平台入口打不开：… | 第 1 步网络或跳转失败（校内网/网络代理） | 换网络重试 |
| 课程平台没有返回 sessionid，可能是登录已过期 | 第 2 步被踢回登录页 | 退出后重新登录 |
| 没能查到当前学期号（queryCurrentXq）… | 第 3 步接口异常 | 稍后重试；持续出现要抓日志 |
| 课程平台在学期 2025-2026-1 下返回 0 门课 | 第 4 步真的没课，或接口字段变了 | 先确认本学期是否选课 |
| 作业刷新失败：没有课程 / 课程清单是空的 | 兜底提示，正常不应再出现 | 重试；仍出现请附日志反馈 |

### 抓日志

设置 → 日志 → 查看日志，筛 `CoursePlatform` 标签，能看到「入口已访问 / 会话已建立 /
没有 sessionid，返回内容开头：…」这几行，足以判断卡在第几步。
日志里不会写账号密码。

## 课表导出 .ics 的日期整体偏移一周

导出前会弹「确认开学第一周」。日期来自校历；没有校历时会按当前周倒推，可能差一周，
在弹窗里点「提前/推后一周」对齐后再导出。
