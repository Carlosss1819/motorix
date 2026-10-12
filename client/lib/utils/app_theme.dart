import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ---------------------------------------------------------------------------
// Paleta: tokens privados, solo se usan dentro de este archivo para construir
// el tema (docs/design-system.md, sección 5).
// ---------------------------------------------------------------------------

abstract final class _Palette {
  static const Color primary = Color(0xFF9B4F55);
  static const Color sidebar = Color(0xFF2B2325);
  static const Color sidebarActive = Color(0xFF43353A);
  static const Color background = Color(0xFFF5F2F1);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color outline = Color(0xFFDDD5D4);
  static const Color textPrimary = Color(0xFF231F20);
  static const Color textSecondary = Color(0xFF6F6566);
  static const Color warning = Color(0xFFC9892B);
  static const Color success = Color(0xFF4F7A5A);
  static const Color danger = Color(0xFFC0392B);

  // Derivados del sidebar para conservar contraste sobre fondo oscuro
  // (docs/design-system.md, sección 10).
  static const Color sidebarText = Color(0xFFFFFFFF);
  static const Color sidebarTextMuted = Color(0xFFBFB4B5);
}

/// Variante suave de un color de estado, usada en chips, avisos y fondos
/// discretos. Se deriva de los tokens, nunca es un color nuevo.
Color _soft(Color color) => color.withValues(alpha: 0.12);

// ---------------------------------------------------------------------------
// ThemeExtension: colores del sistema accesibles desde cualquier contexto.
// ---------------------------------------------------------------------------

/// Colores del sistema de diseño. Se accede con `context.motorixColors`.
@immutable
class MotorixColors extends ThemeExtension<MotorixColors> {
  const MotorixColors({
    required this.primary,
    required this.sidebar,
    required this.sidebarActive,
    required this.sidebarText,
    required this.sidebarTextMuted,
    required this.background,
    required this.surface,
    required this.outline,
    required this.textPrimary,
    required this.textSecondary,
    required this.warning,
    required this.success,
    required this.danger,
  });

  static const double _softOpacity = 0.12;

  static const MotorixColors fallback = MotorixColors(
    primary: _Palette.primary,
    sidebar: _Palette.sidebar,
    sidebarActive: _Palette.sidebarActive,
    sidebarText: _Palette.sidebarText,
    sidebarTextMuted: _Palette.sidebarTextMuted,
    background: _Palette.background,
    surface: _Palette.surface,
    outline: _Palette.outline,
    textPrimary: _Palette.textPrimary,
    textSecondary: _Palette.textSecondary,
    warning: _Palette.warning,
    success: _Palette.success,
    danger: _Palette.danger,
  );

  /// Marca, acciones principales, ítem activo y enlaces.
  final Color primary;

  /// Fondo del sidebar.
  final Color sidebar;

  /// Fondo del ítem activo del sidebar.
  final Color sidebarActive;

  /// Texto e íconos sobre el sidebar (activo o enfocado).
  final Color sidebarText;

  /// Texto e íconos secundarios sobre el sidebar.
  final Color sidebarTextMuted;

  /// Fondo general de la aplicación.
  final Color background;

  /// Paneles, tarjetas, formularios y superficies elevadas.
  final Color surface;

  /// Bordes, divisores y perfiles.
  final Color outline;

  /// Texto principal.
  final Color textPrimary;

  /// Texto secundario, etiquetas y estados "pendiente".
  final Color textSecondary;

  /// Advertencia.
  final Color warning;

  /// Éxito.
  final Color success;

  /// Error, peligro y estado crítico.
  final Color danger;

  /// Variantes suaves de los colores de estado, usadas en chips, avisos y
  /// fondos discretos. Se derivan de los tokens, nunca son colores nuevos.
  Color get primarySoft => primary.withValues(alpha: _softOpacity);
  Color get warningSoft => warning.withValues(alpha: _softOpacity);
  Color get successSoft => success.withValues(alpha: _softOpacity);
  Color get dangerSoft => danger.withValues(alpha: _softOpacity);

  @override
  MotorixColors copyWith({
    Color? primary,
    Color? sidebar,
    Color? sidebarActive,
    Color? sidebarText,
    Color? sidebarTextMuted,
    Color? background,
    Color? surface,
    Color? outline,
    Color? textPrimary,
    Color? textSecondary,
    Color? warning,
    Color? success,
    Color? danger,
  }) {
    return MotorixColors(
      primary: primary ?? this.primary,
      sidebar: sidebar ?? this.sidebar,
      sidebarActive: sidebarActive ?? this.sidebarActive,
      sidebarText: sidebarText ?? this.sidebarText,
      sidebarTextMuted: sidebarTextMuted ?? this.sidebarTextMuted,
      background: background ?? this.background,
      surface: surface ?? this.surface,
      outline: outline ?? this.outline,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      danger: danger ?? this.danger,
    );
  }

  @override
  MotorixColors lerp(ThemeExtension<MotorixColors>? other, double t) {
    if (other is! MotorixColors) {
      return this;
    }
    return MotorixColors(
      primary: Color.lerp(primary, other.primary, t)!,
      sidebar: Color.lerp(sidebar, other.sidebar, t)!,
      sidebarActive: Color.lerp(sidebarActive, other.sidebarActive, t)!,
      sidebarText: Color.lerp(sidebarText, other.sidebarText, t)!,
      sidebarTextMuted: Color.lerp(sidebarTextMuted, other.sidebarTextMuted, t)!,
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      outline: Color.lerp(outline, other.outline, t)!,
      textPrimary: Color.lerp(textPrimary, other.textPrimary, t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
    );
  }
}

/// Acceso cómodo a los colores del sistema desde cualquier widget.
extension MotorixThemeAccess on BuildContext {
  MotorixColors get motorixColors =>
      Theme.of(this).extension<MotorixColors>() ?? MotorixColors.fallback;
}

// ---------------------------------------------------------------------------
// Medidas del sistema (docs/design-system.md, secciones 6.2, 6.3 y 6.4)
// ---------------------------------------------------------------------------

/// Escala de espaciado base de 4 px. No usar otros valores.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// Radios de borde del sistema.
abstract final class AppRadius {
  /// Botones e inputs.
  static const double control = 6;

  /// Paneles, tarjetas, chips, avisos y diálogos.
  static const double panel = 8;

  /// Barras de progreso y elementos tipo "pill".
  static const double pill = 12;
}

/// Escala tipográfica fija: 12 / 14 / 18 / 28.
abstract final class AppFontSizes {
  /// Caption y etiquetas.
  static const double caption = 12;

  /// Cuerpo de texto y controles.
  static const double body = 14;

  /// Título de sección.
  static const double section = 18;

  /// Indicador grande y título de página.
  static const double display = 28;
}

/// Duraciones del movimiento (docs/design-system.md, sección 6.4).
abstract final class AppDuration {
  /// Cambios de estado (hover, focus, selección).
  static const Duration state = Duration(milliseconds: 150);

  /// Aparición o desaparición de elementos.
  static const Duration appear = Duration(milliseconds: 200);

  /// Navegación entre pantallas.
  static const Duration navigate = Duration(milliseconds: 250);
}

/// Medidas estructurales del layout (no tipográficas ni de color).
abstract final class AppMetrics {
  /// Ancho del sidebar expandido.
  static const double sidebarExpandedWidth = 260;

  /// Ancho del sidebar colapsado.
  static const double sidebarCollapsedWidth = 72;

  /// Por debajo de este ancho de ventana el sidebar arranca colapsado.
  static const double narrowBreakpoint = 1000;

  /// Tamaño de los íconos.
  static const double iconSize = 20;
  static const double iconSizeSmall = 16;

  /// Ancho del buscador del header.
  static const double headerSearchWidth = 320;

  /// Ancho máximo del contenido en pantallas muy anchas.
  static const double contentMaxWidth = 1200;

  /// Ancho de la columna de etiquetas en las fichas de detalle.
  static const double detailLabelWidth = 160;

  /// Diámetro del indicador de progreso dentro de un botón.
  static const double spinnerSize = 16;

  /// Ancho del panel de inicio de sesión.
  static const double loginPanelWidth = 420;

  /// Ancho de los diálogos con formulario.
  static const double formDialogWidth = 420;

  /// Ancho mínimo de las tablas con varias columnas.
  static const double tableMinWidth = 880;
}

/// Duración efectiva respetando la preferencia del sistema de reducir
/// movimiento. Usar en toda transición.
Duration motionOf(BuildContext context, Duration base) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : base;

// ---------------------------------------------------------------------------
// Tema de Material 3
// ---------------------------------------------------------------------------

/// Única fuente de estilos de la aplicación.
abstract final class AppTheme {
  /// Tema claro de Motorix (único modo del MVP).
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _Palette.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: _Palette.primary,
      onPrimary: _Palette.surface,
      primaryContainer: _soft(_Palette.primary),
      onPrimaryContainer: _Palette.primary,
      secondary: _Palette.textSecondary,
      onSecondary: _Palette.surface,
      surface: _Palette.surface,
      surfaceContainerLowest: _Palette.background,
      surfaceContainerLow: _Palette.background,
      surfaceContainer: _Palette.surface,
      surfaceContainerHigh: _Palette.surface,
      surfaceContainerHighest: _Palette.surface,
      onSurface: _Palette.textPrimary,
      onSurfaceVariant: _Palette.textSecondary,
      outline: _Palette.outline,
      outlineVariant: _Palette.outline,
      error: _Palette.danger,
      onError: _Palette.surface,
      errorContainer: _soft(_Palette.danger),
      onErrorContainer: _Palette.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: _Palette.background,
      canvasColor: _Palette.background,
      dividerColor: _Palette.outline,
      splashFactory: InkSparkle.splashFactory,
      textTheme: _textTheme(),
      extensions: const <ThemeExtension<dynamic>>[MotorixColors.fallback],
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: _SoftPageTransitionsBuilder(),
          TargetPlatform.iOS: _SoftPageTransitionsBuilder(),
          TargetPlatform.linux: _SoftPageTransitionsBuilder(),
          TargetPlatform.macOS: _SoftPageTransitionsBuilder(),
          TargetPlatform.windows: _SoftPageTransitionsBuilder(),
        },
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: _Palette.sidebar,
        elevation: 0,
        groupAlignment: -1,
        useIndicator: true,
        indicatorColor: _Palette.sidebarActive,
        selectedIconTheme: const IconThemeData(
          color: _Palette.surface,
          size: AppMetrics.iconSize,
        ),
        unselectedIconTheme: const IconThemeData(
          color: _Palette.sidebarTextMuted,
          size: AppMetrics.iconSize,
        ),
        selectedLabelTextStyle: GoogleFonts.ibmPlexSans(
          fontSize: AppFontSizes.body,
          fontWeight: FontWeight.w500,
          color: _Palette.surface,
        ),
        unselectedLabelTextStyle: GoogleFonts.ibmPlexSans(
          fontSize: AppFontSizes.body,
          fontWeight: FontWeight.w400,
          color: _Palette.sidebarTextMuted,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _Palette.surface,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        hintStyle: GoogleFonts.ibmPlexSans(
          fontSize: AppFontSizes.body,
          color: _Palette.textSecondary,
        ),
        labelStyle: GoogleFonts.ibmPlexSans(
          fontSize: AppFontSizes.body,
          color: _Palette.textSecondary,
        ),
        floatingLabelStyle: GoogleFonts.ibmPlexSans(
          fontSize: AppFontSizes.body,
          fontWeight: FontWeight.w500,
          color: _Palette.primary,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: _Palette.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: _Palette.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: _Palette.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: _Palette.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.control),
          borderSide: const BorderSide(color: _Palette.danger, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: _Palette.primary,
          foregroundColor: _Palette.surface,
          minimumSize: const Size(AppSpacing.xxl * 2, AppSpacing.xxl),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          textStyle: GoogleFonts.ibmPlexSans(
            fontSize: AppFontSizes.body,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _Palette.textPrimary,
          minimumSize: const Size(AppSpacing.xxl * 2, AppSpacing.xxl),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
          textStyle: GoogleFonts.ibmPlexSans(
            fontSize: AppFontSizes.body,
            fontWeight: FontWeight.w500,
          ),
          side: const BorderSide(color: _Palette.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _Palette.primary,
          minimumSize: const Size(AppSpacing.xl, AppSpacing.xl),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          textStyle: GoogleFonts.ibmPlexSans(
            fontSize: AppFontSizes.body,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.control),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: _Palette.textSecondary,
          padding: const EdgeInsets.all(AppSpacing.sm),
          visualDensity: VisualDensity.compact,
        ),
      ),
      cardTheme: CardThemeData(
        color: _Palette.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          side: const BorderSide(color: _Palette.outline),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _Palette.background,
        selectedColor: _soft(_Palette.primary),
        labelStyle: GoogleFonts.ibmPlexSans(
          fontSize: AppFontSizes.caption,
          fontWeight: FontWeight.w500,
          color: _Palette.textPrimary,
        ),
        side: const BorderSide(color: _Palette.outline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.xs,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: WidgetStatePropertyAll<Color>(_Palette.background),
        headingTextStyle: GoogleFonts.ibmPlexSans(
          fontSize: AppFontSizes.caption,
          fontWeight: FontWeight.w600,
          color: _Palette.textSecondary,
        ),
        dataTextStyle: GoogleFonts.ibmPlexSans(
          fontSize: AppFontSizes.body,
          color: _Palette.textPrimary,
        ),
        dividerThickness: 1,
        columnSpacing: AppSpacing.xl,
        horizontalMargin: AppSpacing.lg,
        checkboxHorizontalMargin: AppSpacing.sm,
      ),
      dividerTheme: const DividerThemeData(
        color: _Palette.outline,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        waitDuration: AppDuration.state * 2,
        showDuration: AppDuration.appear * 3,
        decoration: BoxDecoration(
          color: _Palette.textPrimary,
          borderRadius: BorderRadius.circular(AppRadius.control),
        ),
        textStyle: GoogleFonts.ibmPlexSans(
          fontSize: AppFontSizes.caption,
          color: _Palette.surface,
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _Palette.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
          side: const BorderSide(color: _Palette.outline),
        ),
        titleTextStyle: GoogleFonts.ibmPlexSans(
          fontSize: AppFontSizes.section,
          fontWeight: FontWeight.w600,
          color: _Palette.textPrimary,
        ),
        contentTextStyle: GoogleFonts.ibmPlexSans(
          fontSize: AppFontSizes.body,
          color: _Palette.textPrimary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: _Palette.textPrimary,
        contentTextStyle: GoogleFonts.ibmPlexSans(
          fontSize: AppFontSizes.body,
          color: _Palette.surface,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.panel),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _Palette.primary,
        linearTrackColor: _Palette.outline,
      ),
    );
  }

  /// Escala tipográfica fija de 4 tamaños con IBM Plex Sans.
  static TextTheme _textTheme() {
    TextStyle style(
      double size,
      FontWeight weight,
      Color color, [
      double? height,
    ]) {
      return GoogleFonts.ibmPlexSans(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );
    }

    final Color primaryText = _Palette.textPrimary;
    final Color secondaryText = _Palette.textSecondary;

    return TextTheme(
      displayLarge: style(AppFontSizes.display, FontWeight.w600, primaryText),
      displayMedium: style(AppFontSizes.display, FontWeight.w600, primaryText),
      displaySmall: style(AppFontSizes.display, FontWeight.w600, primaryText),
      headlineLarge: style(AppFontSizes.display, FontWeight.w600, primaryText),
      headlineMedium: style(AppFontSizes.display, FontWeight.w600, primaryText),
      headlineSmall: style(AppFontSizes.display, FontWeight.w600, primaryText),
      titleLarge: style(AppFontSizes.display, FontWeight.w600, primaryText),
      titleMedium: style(AppFontSizes.section, FontWeight.w600, primaryText),
      titleSmall: style(AppFontSizes.body, FontWeight.w600, primaryText),
      bodyLarge: style(AppFontSizes.body, FontWeight.w400, primaryText),
      bodyMedium: style(AppFontSizes.body, FontWeight.w400, primaryText),
      bodySmall: style(AppFontSizes.caption, FontWeight.w400, secondaryText),
      labelLarge: style(AppFontSizes.body, FontWeight.w500, primaryText),
      labelMedium: style(AppFontSizes.body, FontWeight.w500, primaryText),
      labelSmall: style(AppFontSizes.caption, FontWeight.w500, secondaryText),
    );
  }
}

/// Transición de página discreta: fundido con desplazamiento leve.
class _SoftPageTransitionsBuilder extends PageTransitionsBuilder {
  const _SoftPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return child;
    }
    final CurvedAnimation curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInOut,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0.02, 0),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}
