// 本学期那张课表把「课号 + 节次」和课程名塞进同一个 span，解析出来的
// name 是 `P401048B [02]\n嵌入式系统` —— 课表格子因此被撑成三行。
// 这里钉住两种排版都要解析出干净的课程名。
import 'package:bjtuselfserviceaio/data/remote/parsers/course_parser.dart';
import 'package:flutter_test/flutter_test.dart';

String _table(String cardHtml) =>
    '''
<table>
  <tr><th>节次</th><th>周一</th><th>周二</th><th>周三</th><th>周四</th><th>周五</th><th>周六</th><th>周日</th></tr>
  <tr><td>1</td>$cardHtml<td></td><td></td><td></td><td></td><td></td><td></td></tr>
</table>
''';

/// 课号和课程名挤在一个 span 里（本学期这种排版）。
const _mixedCard = '''
<td>
  <div class="course-card">
    <span>P401048B [02]
嵌入式系统</span>
    <span class="text-muted">海淀西校区,第九教学楼,南413西</span>
    <div style="max-width:120px"><i>张三</i>第1-16周</div>
  </div>
</td>''';

/// 课号单独一行、课程名一个 span（选课课表那种排版）。
const _cleanCard = '''
<td>
  <div class="course-card">
    <span>嵌入式系统课程设计 [本]</span>
    <span class="text-muted">海淀西校区,第九教学楼,南413西</span>
  </div>
</td>''';

void main() {
  test('本学期排版：课号和节次不进课程名', () {
    final course = CourseParser.parseScheduleHtml(
      _table(_mixedCard),
      isCurrentSemester: true,
    ).single;
    expect(course.courseId, 'P401048B');
    expect(course.name, '嵌入式系统');
    expect(course.place, '海淀西校区,第九教学楼,南413西');
  });

  test('同一行挤着写也一样能摘干净', () {
    final course = CourseParser.parseScheduleHtml(
      _table(
        '<td><div><span>M401099B[02] 人工智能的网络应用</span>'
        '<span class="text-muted">逸夫教学楼,YF508</span></div></td>',
      ),
      isCurrentSemester: true,
    ).single;
    expect(course.courseId, 'M401099B');
    expect(course.name, '人工智能的网络应用');
    expect(course.place, '逸夫教学楼,YF508');
  });

  test('结尾的 [本] 标记保留（它标着学期来源）', () {
    final course = CourseParser.parseScheduleHtml(
      _table(_cleanCard),
      isCurrentSemester: false,
    ).single;
    expect(course.name, '嵌入式系统课程设计 [本]');
  });
}
