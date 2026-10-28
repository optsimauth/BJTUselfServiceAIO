// 课程平台会话：这是作业/课件能不能打开的关键一步。
//
// 原项目 `initializeClient()` 的顺序是：先访问 MIS 的课程平台模块入口（走跳转链、
// 共享 MIS Cookie），再打 message.shtml 换 sessionid。漏掉第一步，平台按匿名处理，
// 课程清单返回空数组 —— 界面就只剩一句「没有课程」。
import 'package:bjtuselfserviceaio/core/network/request_manager.dart';
import 'package:bjtuselfserviceaio/data/remote/api/course_api.dart';
import 'package:bjtuselfserviceaio/data/remote/platform_session.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

class _RecordingApi extends CourseApi {
  _RecordingApi() : super(RequestManager(dio: Dio(), ensureLoggedIn: () {}));

  final List<String> calls = [];
  String sessionJson = '{"sessionId":"abc123"}';
  bool moduleFails = false;

  @override
  Future<String> fetchMisCoursePage() async {
    calls.add('module');
    if (moduleFails) throw StateError('入口 500');
    return '<html>课程平台</html>';
  }

  @override
  Future<String> fetchPlatformSessionRaw({Map<String, String>? headers}) async {
    calls.add('session');
    return sessionJson;
  }
}

void main() {
  test('先走 MIS 模块入口，再换 sessionid', () async {
    final api = _RecordingApi();
    final session = CoursePlatformSession(api: api);

    final headers = await session.headers();

    expect(api.calls, ['module', 'session'], reason: '顺序不能反，否则平台按匿名处理');
    expect(headers['sessionid'], 'abc123');
    expect(headers['X-Requested-With'], 'XMLHttpRequest');
    expect(session.sessionId, 'abc123');
  });

  test('sessionid 只换一次，后续请求复用', () async {
    final api = _RecordingApi();
    final session = CoursePlatformSession(api: api);

    await session.headers();
    await session.headers();

    expect(api.calls, ['module', 'session']);
  });

  test('invalidate 之后重新握手（重新登录用）', () async {
    final api = _RecordingApi();
    final session = CoursePlatformSession(api: api);

    await session.headers();
    session.invalidate();
    await session.headers();

    expect(api.calls, ['module', 'session', 'module', 'session']);
  });

  test('拿不到 sessionid 就报错，不再静默用空头去请求', () async {
    final api = _RecordingApi()..sessionJson = '{"sessionId":""}';
    final session = CoursePlatformSession(api: api);

    await expectLater(
      session.headers(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('sessionid'),
        ),
      ),
    );
    expect(session.sessionId, isNull);
  });

  test('返回登录页这种非 JSON 也当失败', () async {
    final api = _RecordingApi()..sessionJson = '<html>请登录</html>';
    final session = CoursePlatformSession(api: api);

    await expectLater(session.headers(), throwsStateError);
  });

  test('MIS 入口打不开时说清是哪一步', () async {
    final api = _RecordingApi()..moduleFails = true;
    final session = CoursePlatformSession(api: api);

    await expectLater(
      session.headers(),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          contains('课程平台入口'),
        ),
      ),
    );
    expect(api.calls, ['module'], reason: '入口失败就不该再去换 sessionid');
  });

  test('失败不缓存：下次调用会重新试', () async {
    final api = _RecordingApi()..sessionJson = '{}';
    final session = CoursePlatformSession(api: api);

    await expectLater(session.headers(), throwsStateError);
    api.sessionJson = '{"sessionId":"ok"}';
    final headers = await session.headers();

    expect(headers['sessionid'], 'ok');
  });
}
