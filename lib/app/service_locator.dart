import 'package:flutter/widgets.dart';

import '../core/database/database.dart';
import '../core/network/cookie_manager.dart';
import '../core/network/http_client.dart';
import '../core/network/request_manager.dart';
import '../core/platform/platform_service.dart';
import '../core/storage/preferences.dart';
import '../core/storage/secure_storage.dart';
import '../data/local/local_stores.dart';
import '../data/remote/api/email_api.dart';
import '../data/remote/api/auth_api.dart';
import '../data/remote/api/calendar_api.dart';
import '../data/remote/api/classroom_api.dart';
import '../data/remote/api/course_api.dart';
import '../data/remote/api/courseware_api.dart';
import '../data/remote/api/exam_api.dart';
import '../data/remote/api/grade_api.dart';
import '../data/remote/api/homework_api.dart';
import '../data/remote/api/update_api.dart';
import '../data/remote/platform_session.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/classroom_repository.dart';
import '../data/repositories/course_repository.dart';
import '../data/repositories/courseware_repository.dart';
import '../data/repositories/exam_repository.dart';
import '../data/repositories/grade_repository.dart';
import '../data/repositories/homework_repository.dart';
import '../data/repositories/platform_course_repository.dart';
import '../data/repositories/sync_coordinator.dart';
import '../features/course/course_controller.dart';
import '../features/exam/exam_controller.dart';
import '../features/grade/grade_controller.dart';
import '../features/homework/homework_controller.dart';
import '../features/email/email_controller.dart';
import '../features/courseware/courseware_controller.dart';
import '../services/captcha/captcha_service.dart';
import '../services/download/download_service.dart';
import '../services/file_picker/file_picker_service.dart';
import '../services/update/update_service.dart';
import '../services/widget/widget_service.dart';
import 'app_config.dart';

/// 手写依赖注入：没有 get_it，没有 codegen。
/// 依赖图一共 5 层（core -> services -> data -> app），构造顺序就是文件顺序。
class ServiceLocator {
  ServiceLocator._({
    required this.config,
    required this.preferences,
    required this.secureStorage,
    required this.cookieManager,
    required this.requestManager,
    required this.platformService,
    required this.database,
    required this.courseLocalStore,
    required this.gradeLocalStore,
    required this.examLocalStore,
    required this.homeworkLocalStore,
    required this.captchaService,
    required this.downloadService,
    required this.filePickerService,
    required this.updateService,
    required this.widgetService,
    required this.accountRepository,
    required this.courseRepository,
    required this.gradeRepository,
    required this.examRepository,
    required this.homeworkRepository,
    required this.coursewareRepository,
    required this.classroomRepository,
    required this.platformCourseRepository,
    required this.syncCoordinator,
    required this.courseController,
    required this.gradeController,
    required this.examController,
    required this.homeworkController,
    required this.emailController,
    required this.coursewareController,
  });

  final AppConfig config;
  final AppPreferences preferences;
  final SecureStorage secureStorage;
  final AppCookieManager cookieManager;
  final RequestManager requestManager;
  final PlatformService platformService;
  final AppDatabase database;

  final CourseLocalStore courseLocalStore;
  final GradeLocalStore gradeLocalStore;
  final ExamLocalStore examLocalStore;
  final HomeworkLocalStore homeworkLocalStore;

  final CaptchaService captchaService;
  final DownloadService downloadService;
  final FilePickerService filePickerService;
  final UpdateService updateService;
  final CourseScheduleWidgetService widgetService;

  final AccountRepository accountRepository;
  final CourseRepository courseRepository;
  final GradeRepository gradeRepository;
  final ExamRepository examRepository;
  final HomeworkRepository homeworkRepository;
  final CoursewareRepository coursewareRepository;
  final ClassroomRepository classroomRepository;
  final PlatformCourseRepository platformCourseRepository;
  final SyncCoordinator syncCoordinator;

  /// 四个业务页共用的 ViewModel；页面销毁不会清掉筛选和内存数据。
  final CourseController courseController;
  final GradeController gradeController;
  final ExamController examController;
  final HomeworkController homeworkController;
  final EmailController emailController;

  /// 课件树常驻内存：进页面直接看到上次的内容，不用每次重新解析缓存。
  final CoursewareController coursewareController;

  static Future<ServiceLocator> bootstrap({
    AppConfig config = AppConfig.defaults,
  }) async {
    final preferences = await AppPreferences.open();
    final secureStorage = SecureStorage();
    // 预热一次：登录页要同步拿预填值，异步读取会让输入框被迟到地覆盖。
    await secureStorage.readCredentials();
    final cookieManager = AppCookieManager();

    // 登录流程本身要发「不登录也能发」的请求，所以这里晚一点再接上真正的门闸。
    late final AccountRepository accountRepository;
    late final EmailApi emailApi;
    final requestManager = RequestManager(
      dio: HttpClientFactory.create(cookieManager: cookieManager),
      ensureLoggedIn: () => accountRepository.requireLogin(),
    );

    final platformService = PlatformServiceFactory.create();
    final database = AppDatabase();

    final courseLocalStore = CourseLocalStore(database.courseDao);
    final gradeLocalStore = GradeLocalStore(database.gradeDao);
    final examLocalStore = ExamLocalStore(database.examDao);
    final homeworkLocalStore = HomeworkLocalStore(database.homeworkDao);

    final captchaService = CaptchaService();
    emailApi = EmailApi(requestManager);

    final downloadService = DownloadService(
      request: requestManager,
      platform: platformService,
      preferences: preferences,
    );
    final filePickerService = const FilePickerService();
    final updateService = UpdateService(
      api: UpdateApi(requestManager),
      downloadService: downloadService,
    );
    final widgetService = CourseScheduleWidgetService(
      platformService: platformService,
    );

    // 课程平台这一套（会话 -> 课程清单 -> 作业/课件）共用一份 CourseApi 和会话，
    // 免得每次同步都重新握手换 sessionid。
    final platformApi = CourseApi(requestManager);
    final platformSession = CoursePlatformSession(api: platformApi);
    final platformCourseRepository = PlatformCourseRepository(
      api: platformApi,
      session: platformSession,
    );

    // 登出时数据库和 Cookie 自己会清，但这两个内存缓存得手动通知。
    accountRepository = AccountRepository(
      api: AuthApi(requestManager),
      captcha: captchaService,
      cookieManager: cookieManager,
      secureStorage: secureStorage,
      preferences: preferences,
      database: database,
      onSessionCleared: () {
        platformSession.invalidate();
        platformCourseRepository.invalidate();
        emailApi.invalidateSession();
      },
    );
    final courseRepository = CourseRepository(
      courseApi: CourseApi(requestManager),
      calendarApi: CalendarApi(requestManager),
      localStore: courseLocalStore,
      downloadService: downloadService,
      preferences: preferences,
    );
    final gradeRepository = GradeRepository(
      api: GradeApi(requestManager),
      localStore: gradeLocalStore,
      preferences: preferences,
      downloadService: downloadService,
    );
    final examRepository = ExamRepository(
      api: ExamApi(requestManager),
      localStore: examLocalStore,
    );
    final homeworkRepository = HomeworkRepository(
      api: HomeworkApi(requestManager),
      localStore: homeworkLocalStore,
      courseRepository: platformCourseRepository,
      session: platformSession,
      downloadService: downloadService,
      platformService: platformService,
    );
    final coursewareRepository = CoursewareRepository(
      api: CoursewareApi(requestManager),
      courseRepository: platformCourseRepository,
      session: platformSession,
      preferences: preferences,
      downloadService: downloadService,
    );
    final classroomRepository = ClassroomRepository(
      api: ClassroomApi(requestManager),
    );

    final emailController = EmailController(api: emailApi);

    final syncCoordinator = SyncCoordinator(
      course: courseRepository,
      grade: gradeRepository,
      exam: examRepository,
      homework: homeworkRepository,
      courseware: coursewareRepository,
      preferences: preferences,
      awaitSession: () => accountRepository.whenSessionReady,
    );
    final courseController = CourseController(
      repository: courseRepository,
      preferences: preferences,
    );
    final gradeController = GradeController(
      repository: gradeRepository,
      studentId: secureStorage.cachedCredentials?.username ?? '',
    );
    final examController = ExamController(repository: examRepository);
    final homeworkController = HomeworkController(
      repository: homeworkRepository,
    );
    // 课件：构造时就把 SharedPreferences 里的树读进内存，页面开箱即用。
    final coursewareController = CoursewareController(
      repository: coursewareRepository,
    );
    await Future.wait([
      courseController.hydrate(),
      gradeController.hydrate(),
      examController.hydrate(),
      homeworkController.hydrate(),
    ]);

    return ServiceLocator._(
      config: config,
      preferences: preferences,
      secureStorage: secureStorage,
      cookieManager: cookieManager,
      requestManager: requestManager,
      platformService: platformService,
      database: database,
      courseLocalStore: courseLocalStore,
      gradeLocalStore: gradeLocalStore,
      examLocalStore: examLocalStore,
      homeworkLocalStore: homeworkLocalStore,
      captchaService: captchaService,
      downloadService: downloadService,
      filePickerService: filePickerService,
      updateService: updateService,
      widgetService: widgetService,
      accountRepository: accountRepository,
      courseRepository: courseRepository,
      gradeRepository: gradeRepository,
      examRepository: examRepository,
      homeworkRepository: homeworkRepository,
      coursewareRepository: coursewareRepository,
      classroomRepository: classroomRepository,
      platformCourseRepository: platformCourseRepository,
      syncCoordinator: syncCoordinator,
      courseController: courseController,
      gradeController: gradeController,
      examController: examController,
      homeworkController: homeworkController,
      emailController: emailController,
      coursewareController: coursewareController,
    );
  }

  Future<void> dispose() async {
    courseController.dispose();
    gradeController.dispose();
    examController.dispose();
    homeworkController.dispose();
    emailController.dispose();
    coursewareController.dispose();
    syncCoordinator.dispose();
    downloadService.dispose();
    await database.close();
  }
}

/// 把 ServiceLocator 挂到 widget 树上。用 getInheritedWidgetOfExactType，
/// 所以 initState 里也能安全取到。
class ServiceScope extends InheritedWidget {
  const ServiceScope({super.key, required this.locator, required super.child});

  final ServiceLocator locator;

  static ServiceLocator of(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<ServiceScope>();
    assert(scope != null, 'ServiceScope 没有挂载，检查 app.dart');
    return scope!.locator;
  }

  @override
  bool updateShouldNotify(ServiceScope oldWidget) =>
      locator != oldWidget.locator;
}
