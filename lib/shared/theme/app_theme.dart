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
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    ),
  );

  static ThemeData dark({Color? dynamicSeed}) => _build(
    ColorScheme.fromSeed(
      seedColor: dynamicSeed ?? AppColors.brand,
      brightness: Brightness.dark,
      dynamicSchemeVariant: DynamicSchemeVariant.tonalSpot,
    ),
  );

  static ThemeData _build(ColorScheme scheme) {
    scheme = _withNeutralSurfaces(scheme);
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
      // 借鉴 Shadcn 的实色面板与细边框，校园蓝留给操作与选中状态。
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
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: AppColors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.sheet,
          side: BorderSide(color: scheme.outlineVariant),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: AppColors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: AppRadius.sheet.topLeft),
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
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: AppColors.transparent,
        elevation: 0,
        height: 80,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant,
          ),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        indicatorColor: scheme.primaryContainer,
        indicatorShape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
        unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
        selectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onSurface,
        ),
        unselectedLabelTextStyle: textTheme.labelLarge?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
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
        shape: RoundedRectangleBorder(borderRadius: AppRadius.chip),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.xs,
        ),
        minVerticalPadding: AppSpacing.md,
        titleTextStyle: textTheme.titleSmall,
        subtitleTextStyle: textTheme.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
        iconColor: scheme.onSurfaceVariant,
        selectedColor: scheme.onPrimaryContainer,
        selectedTileColor: scheme.primaryContainer,
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(AppTouch.minimum, AppTouch.minimum),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLow),
          surfaceTintColor: const WidgetStatePropertyAll(AppColors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: AppRadius.md,
              side: BorderSide(color: scheme.outlineVariant),
            ),
          ),
        ),
      ),
      datePickerTheme: DatePickerThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: AppColors.transparent,
        headerBackgroundColor: scheme.surfaceContainerLow,
        headerForegroundColor: scheme.onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.sheet,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: scheme.primary,
        linearTrackColor: scheme.surfaceContainerHighest,
        borderRadius: AppRadius.bar,
      ),
      // 视觉采用较小圆角，触控区域仍保留 48dp 下限。
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 48),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          minimumSize: const Size(0, AppTouch.minimum),
          shape: RoundedRectangleBorder(borderRadius: AppRadius.control),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: scheme.surfaceContainerLow,
        surfaceTintColor: AppColors.transparent,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.md,
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      // 交互边框用 outline；分组分隔线才使用 outlineVariant。
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        border: OutlineInputBorder(borderRadius: AppRadius.control),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.control,
          // 输入框描边要有 3:1 对比度（docs/UI_SPEC.md 第 2 节 a11y-contrast-ui）：
          // 用 outline，不用更淡的 outlineVariant —— 那是给分隔线用的。
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.control,
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

  static ColorScheme _withNeutralSurfaces(ColorScheme scheme) {
    final neutral = scheme.brightness == Brightness.dark
        ? AppColors.neutralDark
        : AppColors.neutralLight;
    return scheme.copyWith(
      surface: neutral.surface,
      onSurface: neutral.onSurface,
      onSurfaceVariant: neutral.onSurfaceVariant,
      surfaceDim: neutral.surfaceDim,
      surfaceBright: neutral.surfaceBright,
      surfaceContainerLowest: neutral.surfaceContainerLowest,
      surfaceContainerLow: neutral.surfaceContainerLow,
      surfaceContainer: neutral.surfaceContainer,
      surfaceContainerHigh: neutral.surfaceContainerHigh,
      surfaceContainerHighest: neutral.surfaceContainerHighest,
      outline: neutral.outline,
      outlineVariant: neutral.outlineVariant,
    );
  }
}
