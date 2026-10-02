import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'colors.dart';
import 'typography.dart';
import '../../shared/theme/spacing.dart';

enum AppThemeMode {
  system('system'),
  light('light'),
  dark('dark');

  const AppThemeMode(this.storageValue);

  final String storageValue;

  static AppThemeMode fromStorage(String value) =>
      AppThemeMode.values.firstWhere(
        (mode) => mode.storageValue == value,
        orElse: () => AppThemeMode.system,
      );

  ThemeMode get themeMode => switch (this) {
    AppThemeMode.system => ThemeMode.system,
    AppThemeMode.light => ThemeMode.light,
    AppThemeMode.dark => ThemeMode.dark,
  };
}

/// 桌面 / 网页端的滚动行为。
///
/// 这里只做一件事：把鼠标和触控板加进可拖动设备 ——
/// Windows 上按住鼠标左键拖列表能滚。
///
/// 刻意**不**覆写 `buildScrollbar`。桌面端 `ScrollView.primary` 默认解析成
/// false，滚动视图自己拿 controller；而 `ScrollConfiguration` 注入的
/// `Scrollbar` 只能去摸 `PrimaryScrollController`，那个上面永远没有
/// position，于是每一帧抛
/// "The Scrollbar's ScrollController has no ScrollPosition attached"。
/// 想要常驻滚动条就在具体页面写 `Scrollbar(controller: 那个 controller)`——
/// 哪个视图要滚，就把哪个 controller 递进去。
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
    ...super.dragDevices,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

abstract final class AppTheme {
  static ThemeData light({Color? dynamicSeed}) => _build(
    ColorScheme.fromSeed(
      seedColor: dynamicSeed ?? AppColors.brand,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ),
  );

  static ThemeData dark({Color? dynamicSeed}) => _build(
    ColorScheme.fromSeed(
      seedColor: dynamicSeed ?? AppColors.brand,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.fidelity,
    ),
  );

  static ThemeData _build(ColorScheme scheme) {
    final base = ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'NotoSansSC',
      fontFamilyFallback: const ['Microsoft YaHei', 'sans-serif'],
    );
    // 文字颜色显式绑到当前 [scheme] 上，不依赖 ThemeData 自己的推导：
    // 深色模式下那套推导出来的 textTheme 颜色不保证跟 colorScheme 对齐，
    // 一旦对不上就是「深底 + 深字」，成绩/课表这类整页正文全看不见。
    // 字号统一乘 AppTypography.scale，一处控制全局大小。
    // 顺序：先乘字号，再定行高节奏，最后压权重/等宽数字。
    final textTheme = AppTypography.rhythm(
      AppTypography.apply(
        AppTypography.scaleFontSizes(base.textTheme).apply(
          bodyColor: scheme.onSurface,
          displayColor: scheme.onSurface,
          decorationColor: scheme.onSurface,
        ),
      ),
    );
    return base.copyWith(
      textTheme: textTheme,
      // 反色文字（铺在 primary 上的）单独绑 onPrimary，跟正文区分开。
      primaryTextTheme: base.primaryTextTheme.apply(
        bodyColor: scheme.onPrimary,
        displayColor: scheme.onPrimary,
        decorationColor: scheme.onPrimary,
      ),
      scaffoldBackgroundColor: scheme.surface,
      // 卡片是这个 app 里唯一的分组手段（列表、日程、课件全靠它分区），
      // 原来只有「无阴影 + 比背景亮一丁点」，看着就是浮在纸上的一片字。
      // M3 的 outlined card 写法：抬亮填充 + 一根 1px 分隔线，浅色深色都成立。
      cardTheme: base.cardTheme.copyWith(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.lg,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surfaceContainerHigh,
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      // 全屏弹层自带圆角和拖拽把手：原来是一条贴边直上直下的方块，
      // 跟整体圆角语言完全不是一路。
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: AppColors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: scheme.onInverseSurface,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
      ),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: AppColors.transparent,
        // 滚动到下面时不要突然变灰 —— 内容继续从底下穿过更安静。
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorShape: RoundedRectangleBorder(borderRadius: AppRadius.control),
      ),
      // 一根线现在是卡片之间唯一的分隔手段，别让它比卡片边框更重。
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      chipTheme: base.chipTheme.copyWith(
        side: BorderSide(color: scheme.outlineVariant),
        backgroundColor: scheme.surfaceContainerLow,
        labelStyle: textTheme.labelLarge,
        shape: const StadiumBorder(),
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),
      // 统一按钮几何：同一个页面上主按钮 52 高、次按钮 14 圆角，
      // 否则同一个 Card 里的按钮看着像两个 app 拼起来的。
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          side: BorderSide(color: scheme.outlineVariant),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 40),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.md),
        ),
      ),
      // 输入框/下拉框描边默认太深，正文一挨上去像表格线；统一成弱一档的分隔线色。
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: AppRadius.md),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.md,
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      // 选中高亮原来用 Material 默认的紫色系，在一片蓝色里特别跳眼。
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: scheme.primary,
        selectionColor: scheme.primary.withValues(alpha: 0.24),
        selectionHandleColor: scheme.primary,
      ),
      // 手机是滑动翻页，桌面/网页是点击跳转 —— 后者放缩放动画最出戏。
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.fuchsia: FadeForwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
