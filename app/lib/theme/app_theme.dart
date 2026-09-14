import 'package:flutter/material.dart';

/// FogApp 디자인 토큰 — Notion 디자인 시스템(getdesign.md)을 앱에 옮긴 것.
///
/// 원칙은 셋이다.
///
/// 1. **따뜻한 종이 바탕 + 흰 카드.** 페이지는 [canvasSoft], 카드·입력·시트는 [surface].
///    차가운 순백 전체 화면을 만들지 않는다.
/// 2. **구조를 칠하는 색은 파랑 하나.** [primary] 는 주요 행동·링크·선택 상태에만 쓴다.
///    나머지는 잉크와 회색 단계로만 위계를 만든다.
/// 3. **어두운 섬은 하나.** Notion 은 홈 히어로 한 곳만 남색 「밤」 띠로 뒤집는데, 이 앱에서
///    그 자리는 **안개**다. 로그인 화면의 [secondary] 띠가 안개 지도와 같은 결로 앱을 연다.
///
/// 스티커 색([accentGreen] 등)은 **장식·긍정 표시에만** 쓴다 — 버튼이나 배경을 칠하지 않는다.
abstract final class AppColors {
  // ── 브랜드 ─────────────────────────────────────────────
  /// 유일한 구조 강조색. 주요 CTA·링크·포커스.
  static const primary = Color(0xFF0075DE);

  /// [primary] 를 눌렀을 때.
  static const primaryActive = Color(0xFF005BAB);

  /// 남색 「밤」 — 앱에서 한 곳(로그인 히어로)만 쓴다.
  static const secondary = Color(0xFF213183);

  // ── 바탕 ───────────────────────────────────────────────
  /// 카드·입력·시트·앱바.
  static const surface = Color(0xFFFFFFFF);

  /// 페이지 바탕. 순백보다 한 톤 따뜻한 종이색.
  static const canvasSoft = Color(0xFFF6F5F4);

  /// 1px 경계선.
  static const hairline = Color(0xFFE6E6E6);

  /// 입력 필드 테두리 — 경계선보다 한 단계 진하다(rgb 221).
  static const inputBorder = Color(0xFFDDDDDD);

  // ── 글자 ───────────────────────────────────────────────
  /// 본문·제목. 순흑 95% — 화면에서 딱딱하지 않게.
  static const ink = Color(0xF2000000);

  /// 보조 본문.
  static const inkSecondary = Color(0xFF31302E);

  /// 설명·보조 정보.
  static const inkMuted = Color(0xFF615D59);

  /// 캡션·플레이스홀더·비활성.
  static const inkFaint = Color(0xFFA39E98);

  // ── 상태 ───────────────────────────────────────────────
  // 마케팅 문서에는 의미색이 없다(스티커 색이 대신한다). 앱은 오류·파괴 동작을 표시해야
  // 하므로 Notion 앱 안에서 쓰는 빨강 계열을 가져온다.
  static const error = Color(0xFFD44C47);
  static const errorContainer = Color(0xFFFDEBEC);
  static const onErrorContainer = Color(0xFF8A2A26);

  /// 보조 버튼(`FilledButton.tonal`) 바탕. 흰 카드 안에서도 버튼으로 읽혀야 해서 흰색이 아니라
  /// 따뜻한 회색이다 — 지도 위에서만 [mapActionButtonStyle] 이 흰색으로 바꾼다.
  static const buttonSecondary = Color(0xFFEFEEEC);

  /// 안내 배너 바탕. 파랑을 «칠하지» 않으려고 아주 옅게만 쓴다 — 글자는 잉크다.
  static const infoContainer = Color(0xFFE7F1FB);

  // ── 스티커(장식 전용) ─────────────────────────────────
  static const accentSky = Color(0xFF62AEF0);
  static const accentPurple = Color(0xFFD6B6F6);
  static const accentPink = Color(0xFFFF64C8);
  static const accentOrange = Color(0xFFDD5B00);
  static const accentTeal = Color(0xFF2A9D99);

  /// 긍정 표시(체크·완료)에 쓴다 — 스펙이 「affirmative ticks」로 허락한 유일한 용도.
  static const accentGreen = Color(0xFF1AAE39);
}

/// 모서리 반경.
abstract final class AppRadii {
  /// 입력 필드·작은 태그. 버튼보다 «각지게» 둔다.
  static const xs = 4.0;

  /// 목록 행·상태 알약.
  static const sm = 5.0;

  /// 보조 버튼·작은 카드.
  static const md = 8.0;

  /// 카드·배너·지도 위 떠 있는 패널.
  static const lg = 12.0;

  /// 큰 컨테이너·바텀시트 윗모서리.
  static const xl = 16.0;
}

/// 간격 — 8px 기반.
abstract final class AppSpacing {
  static const xxs = 4.0;
  static const xs = 8.0;
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xxl = 32.0;
}

/// Notion 의 「거의 안 보이는」 그림자. 여러 겹의 아주 옅은 층으로 종이에서 살짝 뜬 느낌만 낸다.
///
/// Material 의 `elevation` 은 한 겹이라 이 느낌이 안 나므로, 지도 위에 떠 있는 패널처럼
/// 직접 그리는 곳은 [AppShadows.soft] 를 쓴다.
abstract final class AppShadows {
  /// Level 1 — 떠 있는 카드·지도 위 패널.
  static const soft = [
    BoxShadow(color: Color(0x03000000), offset: Offset(0, 0.175), blurRadius: 1.041),
    BoxShadow(color: Color(0x05000000), offset: Offset(0, 0.8), blurRadius: 2.925),
    BoxShadow(color: Color(0x07000000), offset: Offset(0, 2.025), blurRadius: 7.847),
    BoxShadow(color: Color(0x0A000000), offset: Offset(0, 4), blurRadius: 18),
  ];
}

/// 글자 체계.
///
/// Notion 은 제목을 **무겁게(700) + 좁게(음의 자간)** 두고 본문은 400 으로 차분하게 둔다 —
/// 둘의 대비가 유일한 표현 수단이다.
///
/// 📌 폰트는 지정하지 않는다(안드로이드 기본: Roboto + Noto Sans CJK KR). Notion 의 Inter 는
///    한글 글리프가 없어서, 쓰려면 Inter 기반 한글 폰트(Pretendard 등)를 번들해야 한다.
///
/// 📌 자간은 스펙의 px 값을 **글자 크기 대비 비율**로 옮겼다. 스펙의 64px 제목용 −2.125px 를
///    앱의 작은 크기에 그대로 쓰면 한글이 뭉개진다.
///
/// 📌 본문 행간은 스펙(15px/1.33)보다 조금 넓힌다(1.47). 한글은 라틴보다 글자 면이 꽉 차서
///    같은 행간에서 더 답답하게 읽힌다.
///
/// 📌 캡션([TextTheme.bodySmall])은 스펙의 14px 대신 13px 이다. 지도 위 배너·카드 메타 정보가
///    이 크기를 쓰는데, 14px 이면 한 줄 배너가 세 줄로 접혀 지도를 가린다.
TextTheme _textTheme() {
  const ink = AppColors.ink;
  return const TextTheme(
    displayLarge: TextStyle(fontSize: 40, fontWeight: FontWeight.w700, height: 1.1, letterSpacing: -1.0, color: ink),
    displayMedium: TextStyle(fontSize: 34, fontWeight: FontWeight.w700, height: 1.12, letterSpacing: -0.8, color: ink),
    displaySmall: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, height: 1.15, letterSpacing: -0.6, color: ink),
    headlineLarge: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.6, color: ink),
    headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, height: 1.23, letterSpacing: -0.625, color: ink),
    headlineSmall: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.27, letterSpacing: -0.25, color: ink),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, height: 1.4, letterSpacing: -0.125, color: ink),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.5, color: ink),
    titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, height: 1.4, color: ink),
    bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400, height: 1.5, color: ink),
    bodyMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w400, height: 1.47, color: ink),
    bodySmall: TextStyle(fontSize: 13, fontWeight: FontWeight.w400, height: 1.45, color: AppColors.inkMuted),
    labelLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5),
    labelMedium: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, height: 1.4),
    labelSmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.33, letterSpacing: 0.125),
  );
}

/// 앱 전체 색 역할.
///
/// 🔴 `surfaceTint` 를 투명으로 둔다. Material 3 는 `elevation` 이 있는 표면에 [primary] 를
///    옅게 섞는데, 그러면 흰 카드·지도 위 패널이 전부 푸르스름해져 「파랑은 행동에만」이 깨진다.
///
/// `secondaryContainer`(보조 버튼 바탕)는 **흰색이 아니라 따뜻한 회색**이다. 흰색으로 두면 흰 카드
/// 안의 `FilledButton.tonal`(예: 동행 추천의 「동행 요청」)이 배경에 녹아 버튼으로 안 보인다.
/// 지도 위에서는 [mapActionButtonStyle] 이 흰 알약 + 경계선 + 그림자(Notion `button-secondary`)로 바꾼다.
ColorScheme _colorScheme() {
  return const ColorScheme(
    brightness: Brightness.light,
    primary: AppColors.primary,
    onPrimary: AppColors.surface,
    primaryContainer: AppColors.infoContainer,
    onPrimaryContainer: AppColors.ink,
    secondary: AppColors.secondary,
    onSecondary: AppColors.surface,
    secondaryContainer: AppColors.buttonSecondary,
    onSecondaryContainer: AppColors.ink,
    tertiary: AppColors.secondary,
    onTertiary: AppColors.surface,
    tertiaryContainer: AppColors.canvasSoft,
    onTertiaryContainer: AppColors.ink,
    error: AppColors.error,
    onError: AppColors.surface,
    errorContainer: AppColors.errorContainer,
    onErrorContainer: AppColors.onErrorContainer,
    surface: AppColors.surface,
    onSurface: AppColors.ink,
    onSurfaceVariant: AppColors.inkMuted,
    surfaceDim: Color(0xFFEBEAE8),
    surfaceBright: AppColors.surface,
    surfaceContainerLowest: AppColors.surface,
    surfaceContainerLow: Color(0xFFFBFAF9),
    surfaceContainer: AppColors.canvasSoft,
    surfaceContainerHigh: Color(0xFFF1F0EE),
    surfaceContainerHighest: Color(0xFFEBEAE8),
    outline: AppColors.inputBorder,
    outlineVariant: AppColors.hairline,
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: AppColors.inkSecondary,
    onInverseSurface: AppColors.canvasSoft,
    inversePrimary: AppColors.accentSky,
    surfaceTint: Color(0x00000000),
  );
}

/// 지도 위에 떠 있는 버튼 스타일 — 전역 [FilledButtonThemeData] 에 경계선·옅은 그림자를 **병합**한다.
///
/// 흰 알약(`FilledButton.tonal`)은 페이지 위에서는 괜찮지만 밝은 지도 타일 위에서는 묻힌다.
/// 하위 트리에 `FilledButtonTheme` 을 새로 두면 전역 스타일을 «대체»해 알약 모양·글자 크기까지
/// 사라지므로, 반드시 전역 스타일과 합쳐서 쓴다.
ButtonStyle mapActionButtonStyle(ThemeData theme) {
  return FilledButton.styleFrom(
    backgroundColor: AppColors.surface,
    foregroundColor: AppColors.ink,
    side: const BorderSide(color: AppColors.hairline),
    elevation: 2,
    shadowColor: const Color(0x33000000),
  ).merge(theme.filledButtonTheme.style);
}

/// 앱 테마.
ThemeData buildAppTheme() {
  final colors = _colorScheme();
  // 🔴 기본 타이포그래피(플랫폼 폰트 계열 포함)에 «병합»한 것을 쓴다. 원시 [_textTheme] 을 버튼
  //    스타일에 그대로 넘기면 fontFamily 가 비어, 화면 글자와 버튼 글자가 다른 경로로 폰트를 찾는다.
  final text = ThemeData(useMaterial3: true, colorScheme: colors).textTheme.merge(_textTheme());

  const hairlineSide = BorderSide(color: AppColors.hairline);
  const pill = StadiumBorder();
  final roundedMd = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md));
  final roundedLg = RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.lg));

  // 버튼 공통 크기 — 모바일 최소 터치 영역 44 를 지킨다.
  const buttonMinSize = Size(64, 44);
  const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 10);

  OutlineInputBorder inputBorder(Color color, {double width = 1}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadii.xs),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    textTheme: text,
    scaffoldBackgroundColor: AppColors.canvasSoft,
    splashFactory: InkRipple.splashFactory,
    dividerColor: AppColors.hairline,

    appBarTheme: AppBarThemeData(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: text.titleLarge,
      shape: const Border(bottom: hairlineSide),
    ),

    // 주요 CTA — 파란 알약. `FilledButton.tonal` 도 이 모양을 받되 색은 흰색(secondaryContainer)이다.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: pill,
        minimumSize: buttonMinSize,
        padding: buttonPadding,
        textStyle: text.labelLarge,
        elevation: 0,
        shadowColor: Colors.transparent,
      ),
    ),

    // 보조(유틸리티) 버튼 — 흰 바탕, 경계선, 8px.
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        backgroundColor: AppColors.surface,
        side: hairlineSide,
        shape: roundedMd,
        minimumSize: buttonMinSize,
        padding: buttonPadding,
        textStyle: text.labelLarge,
      ),
    ),

    // 글자 버튼은 링크다 — 파랑이 허락된 자리.
    //
    // 🔴 채움 버튼의 [AppColors.primary](#0075DE)가 아니라 한 단계 짙은 [AppColors.primaryActive] 를 쓴다.
    //    #0075DE 글자는 흰 바탕에서 4.56:1 로 겨우 통과하고, 지도 근접 배너(infoContainer)
    //    위에서는 3.99:1 로 AA(4.5:1)에 못 미친다 — 거기 있는 링크가 「인증하러 가기」다.
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primaryActive,
        shape: roundedMd,
        textStyle: text.labelLarge,
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppColors.ink),
    ),

    // 지도 위 원형 토글 — 흰 원 + 잉크 아이콘. 파랑으로 칠하지 않는다.
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.surface,
      foregroundColor: AppColors.ink,
      elevation: 2,
      focusElevation: 2,
      hoverElevation: 3,
      highlightElevation: 1,
      shape: CircleBorder(side: hairlineSide),
    ),

    // 카드 — 그림자 없이 경계선 한 줄(Level 0).
    cardTheme: CardThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.lg),
        side: hairlineSide,
      ),
    ),

    // 입력 — 알약이 아니라 각진 4px. 버튼과의 대비가 의도다.
    inputDecorationTheme: InputDecorationThemeData(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: inputBorder(AppColors.inputBorder),
      enabledBorder: inputBorder(AppColors.inputBorder),
      focusedBorder: inputBorder(AppColors.primary, width: 1.5),
      errorBorder: inputBorder(AppColors.error),
      focusedErrorBorder: inputBorder(AppColors.error, width: 1.5),
      labelStyle: text.bodyMedium?.copyWith(color: AppColors.inkMuted),
      floatingLabelStyle: text.bodySmall?.copyWith(color: AppColors.primary),
      hintStyle: text.bodyMedium?.copyWith(color: AppColors.inkFaint),
    ),

    // 알약 배지 — 흰 바탕 + 파란 글자(badge-pill). 정복률 표시가 이것을 쓴다.
    chipTheme: ChipThemeData(
      backgroundColor: AppColors.surface,
      side: hairlineSide,
      shape: pill,
      labelStyle: text.labelMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
      padding: const EdgeInsets.symmetric(horizontal: 4),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 6,
      shape: roundedLg,
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium?.copyWith(color: AppColors.inkSecondary),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      dragHandleColor: AppColors.hairline,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.xl)),
      ),
    ),

    // 토스트 — 흰 카드 + 옅은 그림자(ex-toast). 지도 위에서도 읽히도록 경계선을 둔다.
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.surface,
      contentTextStyle: text.bodyMedium,
      actionTextColor: AppColors.primary,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.md),
        side: hairlineSide,
      ),
    ),

    dividerTheme: const DividerThemeData(color: AppColors.hairline, thickness: 1, space: 1),

    checkboxTheme: CheckboxThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.xs)),
      side: const BorderSide(color: AppColors.inkFaint, width: 1.5),
    ),

    listTileTheme: const ListTileThemeData(iconColor: AppColors.inkMuted),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.primary,
      linearTrackColor: AppColors.hairline,
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: roundedMd,
      textStyle: text.bodyMedium,
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: AppColors.inkSecondary,
        borderRadius: BorderRadius.circular(AppRadii.sm),
      ),
      textStyle: text.bodySmall?.copyWith(color: AppColors.surface),
    ),
  );
}
