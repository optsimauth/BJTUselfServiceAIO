// 课件的变更检测：新增 / 改名换大小 / 删除，规则跟成绩作业那一套一致。
import 'package:bjtuselfserviceaio/core/state/sync_module.dart';
import 'package:bjtuselfserviceaio/core/state/sync_result.dart';
import 'package:bjtuselfserviceaio/data/models/courseware/courseware_model.dart';
import 'package:bjtuselfserviceaio/features/courseware/courseware_tree.dart';
import 'package:flutter_test/flutter_test.dart';

CoursewareNode _file(
  String id,
  String name, {
  String size = '1.0 MB',
  CoursewareKind kind = CoursewareKind.res,
  List<CoursewareNode> children = const [],
}) => CoursewareNode(
  id: id,
  name: name,
  kind: kind,
  sizeText: size,
  rpId: 'rp-$id',
  children: children,
);

SyncResult _result(List<CoursewareNode> remote, List<CoursewareNode> local) =>
    SyncResult.fromChanges(
      SyncModule.courseware,
      CoursewareTree.detectChanges(
        remote: CoursewareTree.flatten(remote),
        local: CoursewareTree.flatten(local),
      ),
      describe: CoursewareTree.describeChange,
    );

void main() {
  final before = [
    _file(
      'c1',
      '嵌入式系统',
      kind: CoursewareKind.course,
      children: [
        _file(
          'b1',
          '参考资料',
          kind: CoursewareKind.bag,
          children: [_file('r1', '芯片手册.pdf'), _file('r2', '电路图.pdf')],
        ),
      ],
    ),
  ];

  test('新增：新出现的文件算新增', () {
    final after = [
      _file(
        'c1',
        '嵌入式系统',
        kind: CoursewareKind.course,
        children: [
          _file(
            'b1',
            '参考资料',
            kind: CoursewareKind.bag,
            children: [
              _file('r1', '芯片手册.pdf'),
              _file('r2', '电路图.pdf'),
              _file('r9', '新增讲义.pdf'),
            ],
          ),
        ],
      ),
    ];
    final result = _result(after, before);
    expect(result.added, 1);
    expect(result.modified, 0);
    expect(result.deleted, 0);
    expect(result.message, '课件：新增 1');
  });

  test('改名或换大小算变更，下载次数变化不算', () {
    final renamed = [
      _file(
        'c1',
        '嵌入式系统',
        kind: CoursewareKind.course,
        children: [
          _file(
            'b1',
            '参考资料',
            kind: CoursewareKind.bag,
            children: [_file('r1', '芯片手册（修订）.pdf'), _file('r2', '电路图.pdf')],
          ),
        ],
      ),
    ];
    expect(_result(renamed, before).modified, 1);

    final resized = [
      _file(
        'c1',
        '嵌入式系统',
        kind: CoursewareKind.course,
        children: [
          _file(
            'b1',
            '参考资料',
            kind: CoursewareKind.bag,
            children: [
              _file('r1', '芯片手册.pdf', size: '2.0 MB'),
              _file('r2', '电路图.pdf'),
            ],
          ),
        ],
      ),
    ];
    expect(_result(resized, before).modified, 1);
  });

  test('删除：远端没有的节点算删除', () {
    final after = [
      _file(
        'c1',
        '嵌入式系统',
        kind: CoursewareKind.course,
        children: [
          _file(
            'b1',
            '参考资料',
            kind: CoursewareKind.bag,
            children: [_file('r1', '芯片手册.pdf')],
          ),
        ],
      ),
    ];
    final result = _result(after, before);
    expect(result.deleted, 1);
    expect(result.modified, 0);
  });

  test('层级扁平化：课程 / 文件夹 / 文件都进比较', () {
    expect(CoursewareTree.flatten(before).map((node) => node.name), [
      '嵌入式系统',
      '参考资料',
      '芯片手册.pdf',
      '电路图.pdf',
    ]);
  });

  test('变更详情：标题带课程名，字段列出前后', () {
    final after = [
      _file(
        'c1',
        '嵌入式系统',
        kind: CoursewareKind.course,
        children: [
          _file(
            'b1',
            '参考资料',
            kind: CoursewareKind.bag,
            children: [
              _file('r1', '芯片手册.pdf', size: '9.9 MB'),
              _file('r2', '电路图.pdf'),
            ],
          ),
        ],
      ),
    ];
    final detail = _result(after, before).details.single;
    expect(detail.title, contains('芯片手册.pdf'));
    expect(detail.fields.firstWhere((f) => f.label == '大小').before, '1.0 MB');
    expect(detail.fields.firstWhere((f) => f.label == '大小').after, '9.9 MB');
  });

  test('没有变化时 result 不算 hasChanges（首页不弹提示）', () {
    expect(_result(before, before).hasChanges, isFalse);
  });
}
