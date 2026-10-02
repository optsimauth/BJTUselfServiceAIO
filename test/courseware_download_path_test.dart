import 'package:bjtuselfserviceaio/data/models/courseware/courseware_model.dart';
import 'package:bjtuselfserviceaio/features/courseware/courseware_tree.dart';
import 'package:flutter_test/flutter_test.dart';

CoursewareNode _file(String id, String name, {String? saved}) => CoursewareNode(
  id: id,
  name: name,
  kind: CoursewareKind.res,
  rpId: 'rp-$id',
  downloadedPath: saved,
);

CoursewareNode _bag(String id, String name, List<CoursewareNode> children) =>
    CoursewareNode(
      id: id,
      name: name,
      kind: CoursewareKind.bag,
      children: children,
    );

CoursewareNode _course(List<CoursewareNode> children) => CoursewareNode(
  id: '1',
  name: '高等数学A',
  kind: CoursewareKind.course,
  children: children,
);

void main() {
  final tree = _course([
    _file('r1', '课件.pdf'),
    _bag('b1', '第1章', [
      _file('r2', '1.1 函数与极限.pdf'),
      _bag('b2', '习题', [_file('r3', '习题1.docx')]),
    ]),
    _file('r4', '别的.pdf', saved: '/x/别的.pdf'),
  ]);

  group('downloadItemsOf 递归下载的文件夹结构', () {
    test('课程 -> 文件夹 -> 文件，层级原样保留', () {
      final items = CoursewareTree.downloadItemsOf(tree);
      expect(
        {for (final item in items) item.file.name: item.folders},
        {
          '课件.pdf': ['高等数学A'],
          '1.1 函数与极限.pdf': ['高等数学A', '第1章'],
          '习题1.docx': ['高等数学A', '第1章', '习题'],
        },
      );
    });

    test('已下载的文件不进批量列表', () {
      final items = CoursewareTree.downloadItemsOf(tree);
      expect(items.any((item) => item.file.name == '别的.pdf'), isFalse);
      expect(items, hasLength(3));
    });

    test('从文件夹开下载时，文件夹自己当第一层', () {
      final folder = tree.children[1];
      final items = CoursewareTree.downloadItemsOf(folder);
      expect(items.first.folders, ['第1章']);
    });

    test('深度上限兜住自引用文件夹', () {
      final loop = _bag('b9', '自引用', [
        _bag('b9', '自引用', [_file('r9', '死循环.pdf')]),
      ]);
      expect(CoursewareTree.downloadItemsOf(loop, maxDepth: 1), isEmpty);
    });
  });

  group('foldersOf 单文件下载的位置', () {
    test('直接挂在课程下的文件落在课程文件夹', () {
      expect(CoursewareTree.foldersOf([tree], 'res-r1'), ['高等数学A']);
    });

    test('深层文件带上每一层', () {
      expect(CoursewareTree.foldersOf([tree], 'res-r3'), [
        '高等数学A',
        '第1章',
        '习题',
      ]);
    });

    test('找不到的 identity 返回空', () {
      expect(CoursewareTree.foldersOf([tree], 'res-nope'), isEmpty);
    });
  });

  group('safeSegment 落盘名的净化', () {
    test('Windows 非法字符换成全角', () {
      expect(CoursewareTree.safeSegment(r'第1章:讲义\附录'), '第1章：讲义＼附录');
    });

    test('结尾的点和空格去掉', () {
      expect(CoursewareTree.safeSegment('第1章. '), '第1章');
    });

    test('空名和 .. 给兜底名，不然会写到目录上一层', () {
      expect(CoursewareTree.safeSegment(''), '_');
      expect(CoursewareTree.safeSegment('..'), '_');
    });

    test('正常名字原样保留', () {
      expect(CoursewareTree.safeSegment('第1章 极限'), '第1章 极限');
    });
  });

  group('树层级缩进', () {
    test('越深缩进越多，顶层不缩进', () {
      expect(CoursewareTree.indentOf(0), 0);
      expect(CoursewareTree.indentOf(1), 16);
      expect(CoursewareTree.indentOf(2), 32);
      expect(CoursewareTree.indentOf(3), 48);
    });

    test('第 5 层封顶，再深也不挤掉文件名', () {
      expect(CoursewareTree.indentOf(5), 80);
      expect(CoursewareTree.indentOf(9), 80);
    });
  });
}
