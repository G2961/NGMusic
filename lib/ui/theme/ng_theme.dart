import 'package:flutter/material.dart';

import 'theme_controller.dart';

export 'theme_controller.dart';

/// Палитра и формы Newgrounds — две дизайн-эпохи на выбор:
/// классический 2015 (текстуры, Pakenham) и современный 2024 (плоский
/// тёмный, Arial). Все цвета раздаются через топ-левел геттеры
/// (`ngGold`, `ngPodBg`, …) поверх [ThemeController.palette] — при смене
/// темы в Settings весь UI перекрашивается без перезапуска.
///
/// Значения 2015 — из `ng_publish.css` архива 2015 года; значения 2024 —
/// из декодированного `ng2024.css`. В комментариях исходный селектор.

// ── Базовые цвета (геттеры над активной палитрой) ────────────────────────────

Color get ngBlack => themeCtl.palette.black; // body
Color get ngPodBg => themeCtl.palette.podBg; // div.pod-body
Color get ngPodBorder => themeCtl.palette.podBorder; // рамка пода
Color get ngPodBotBorder => themeCtl.palette.podBotBorder; // div.podbot
Color get ngRowAlt => themeCtl.palette.rowAlt; // tr.alt
Color get ngMainCol => themeCtl.palette.mainCol; // колонка страницы

Color get ngGold => themeCtl.palette.gold; // цвет ссылок NG
Color get ngText => themeCtl.palette.text; // body color
Color get ngWhite => themeCtl.palette.white;
Color get ngDim => themeCtl.palette.dim; // h5, th, .pagenav
Color get ngDimmer => themeCtl.palette.dimmer; // blockquote
Color get ngInk => themeCtl.palette.ink; // текст на золотом фоне
Color get ngHairline => themeCtl.palette.hairline; // тонкие границы

Color get ngBrown => themeCtl.palette.brown; // podtop (gold skin)
Color get ngBrownMid => themeCtl.palette.brownMid; // .pagenav a>span
Color get ngOrange => themeCtl.palette.orange;
Color get ngOrangeDeep => themeCtl.palette.orangeDeep;
Color get ngRed => themeCtl.palette.red; // .remove
Color get ngGreen => themeCtl.palette.green; // green skin accent
Color get ngPodGreen => themeCtl.palette.podGreen; // body.green div.podtop
Color get ngRowAltGreen => themeCtl.palette.rowAltGreen;

// ── Плеер ────────────────────────────────────────────────────────────────────

Color get ngPlayerYellow => themeCtl.palette.playerYellow;
Color get ngPlayerStripe => themeCtl.palette.playerStripe;
Color get ngPlayerBarTop => themeCtl.palette.playerBarTop;
Color get ngPlayerBarBot => themeCtl.palette.playerBarBot;
Color get ngSeekBorder => themeCtl.palette.seekBorder;
Color get ngVizTop => themeCtl.palette.vizTop;
Color get ngVizMid => themeCtl.palette.vizMid;
Color get ngVizBot => themeCtl.palette.vizBot;

// ── Пути к текстурам ─────────────────────────────────────────────────────────

class NgTex {
  // Текстуры 2015: активны в классической теме, в современной не используются.
  static const podtopGold = 'assets/ng2015/tex/podtop-gold.jpg';
  static const podtopGreen = 'assets/ng2015/tex/podtop-green.jpg';
  static const podtopBlue = 'assets/ng2015/tex/podtop-blue.jpg';
  static const podtopRed = 'assets/ng2015/tex/podtop-red.jpg';
  static const podtopPink = 'assets/ng2015/tex/podtop-pink.jpg';
  static const podBody = 'assets/ng2015/tex/pod-body.jpg';
  static const podbreaker = 'assets/ng2015/tex/podbreaker.jpg';
  static const podstripe = 'assets/ng2015/tex/podstripe.png';
  static const mainColumn = 'assets/ng2015/tex/body-gold.png';
  static const linkPlate = 'assets/ng2015/tex/link-plate.png';
  static const linkPlateHover = 'assets/ng2015/tex/link-plate-hover.png';
  static const buttonNormal = 'assets/ng2015/tex/button-normal.png';
  static const buttonHover = 'assets/ng2015/tex/button-hover.png';
  static const buttonDisabled = 'assets/ng2015/tex/button-disabled.png';
  static const input = 'assets/ng2015/tex/input-gold.jpg';

  static const navbarPlates = 'assets/ng2015/tex/navbar.jpg';
  static const navTop = 'assets/ng2015/tex/nav-top.png';
  static const footerStripes = 'assets/ng2015/tex/footer-stripes.png';

  static const logo = 'assets/ng2015/logo-ngmusic.png';
  static const logoNg2015 = 'assets/ng2015/logo.png';

  /// Лого шапки 2024: танк + «NEWGROUNDS AUDIO PORTAL» (assets/header_logo.png).
  static const logoHeader2024 = 'assets/header_logo.png';
  static const logoTiny = 'assets/ng2015/logo-tiny.png';
  static const defaultAudioIcon = 'assets/ng2015/icon-audio-default.png';
  static const starsEmpty = 'assets/ng2015/stars-empty.png';
  static const starsFull = 'assets/ng2015/stars-full.png';

  static const trophies = 'assets/ng2015/ul-trophies.png';

  /// Лица votebar 2015 (зелёный скин аудио-портала), спрайт 300×230.
  static const voteFaces = 'assets/ng2015/vp/vote-darn.png';

  /// Звёзды рейтинга 2024 — спрайт 36×72 (пустые сверху, залитые снизу).
  static const starScore2024 = 'assets/ng2024/sprites/star-score.webp';

  /// Звёзды-кнопки голосования 2024 — спрайт 150×666 (одна звезда 150×134,
  /// 5 состояний: hover/idle/checked/blam, @2x).
  static const starSelect2024 = 'assets/ng2024/sprites/star-select-2.webp';

  /// Иконки настроения votebar 2024 («Steve reacts») — 210×2035, 11 кадров
  /// по 185px (@2x), кадр N = голос N (0..10).
  static const steveReact2024 = 'assets/ng2024/sprites/SteveReact4.webp';

  /// Кнопки плеера 2024 — спрайт 200×100: play слева (64×64), pause справа.
  static const playbackButtons2024 =
      'assets/ng2024/sprites/playback-buttons.webp';

  static String h2(String name) => 'assets/ng2015/h2/$name.png';

  static String a15(String name, {bool dark = false}) =>
      'assets/ng2015/a15/$name${dark ? '-dark' : ''}.png';
}

// ── Типографика ──────────────────────────────────────────────────────────────

/// 2015 — Pakenham («headerfont» из CSS 2015), 2024 — Arial.
String get ngHeaderFont => themeCtl.textured ? 'Pakenham' : 'Arial';

TextStyle get ngH2 => themeCtl.textured
    ? TextStyle(
        fontFamily: 'Pakenham',
        fontSize: 22,
        height: 1.1,
        color: ngWhite,
      )
    : TextStyle(
        fontFamily: 'Arial',
        fontSize: 17,
        height: 1.2,
        color: ngWhite,
        fontWeight: FontWeight.w500,
      );

TextStyle get ngH3 => themeCtl.textured
    ? TextStyle(
        fontFamily: 'Pakenham',
        fontSize: 14,
        fontStyle: FontStyle.italic,
        fontWeight: FontWeight.bold,
        color: ngWhite,
      )
    : TextStyle(
        fontFamily: 'Arial',
        fontSize: 14,
        fontStyle: FontStyle.normal,
        fontWeight: FontWeight.bold,
        color: ngWhite,
      );

TextStyle get ngLink => themeCtl.textured
    ? TextStyle(
        fontFamily: 'Pakenham',
        fontSize: 12,
        fontWeight: FontWeight.bold,
        color: ngGold,
      )
    : TextStyle(
        fontFamily: 'Arial',
        fontSize: 13,
        fontWeight: FontWeight.normal,
        color: ngGold,
      );

TextStyle get ngBody => themeCtl.textured
    ? TextStyle(fontFamily: 'Pakenham', fontSize: 12, color: ngText)
    : TextStyle(fontFamily: 'Arial', fontSize: 13, color: ngText);
TextStyle get ngBodySmall => themeCtl.textured
    ? TextStyle(fontFamily: 'Pakenham', fontSize: 11, color: ngText)
    : TextStyle(fontFamily: 'Arial', fontSize: 12, color: ngText);
TextStyle get ngLabel => themeCtl.textured
    ? TextStyle(fontFamily: 'Pakenham', fontSize: 11, color: ngDim)
    : TextStyle(fontFamily: 'Arial', fontSize: 12, color: ngDim);

// ── Скины подов ──────────────────────────────────────────────────────────────

enum NgSkin { gold, green, blue, red, pink }

extension NgSkinX on NgSkin {
  // 2015: текстурные шапки; 2024: плоский градиент.
  String get podtop => switch (this) {
        NgSkin.gold => NgTex.podtopGold,
        NgSkin.green =>
          themeCtl.textured ? NgTex.podtopGreen : NgTex.podtopGold,
        NgSkin.blue => NgTex.podtopBlue,
        NgSkin.red => NgTex.podtopRed,
        NgSkin.pink => NgTex.podtopPink,
      };

  Color get podtopFill => themeCtl.textured
      ? switch (this) {
          NgSkin.gold => ngBrown,
          NgSkin.green => ngPodGreen,
          NgSkin.blue => const Color(0xFF14283C),
          NgSkin.red => const Color(0xFF441414),
          NgSkin.pink => const Color(0xFF3C1428),
        }
      : ngBrown; // в 2024 шапки подов одинаковые

  Color get rowAlt =>
      themeCtl.textured && this == NgSkin.green ? ngRowAltGreen : ngRowAlt;
}

// ── ThemeData ────────────────────────────────────────────────────────────────

ThemeData get ngTheme => ThemeData(
      colorScheme: ColorScheme.dark(
        primary: ngGold,
        secondary: ngOrange,
        surface: ngPodBg,
        onSurface: ngText,
        onPrimary: ngInk,
        error: ngRed,
      ),
      scaffoldBackgroundColor: ngBlack,
      canvasColor: ngBlack,
      appBarTheme: AppBarTheme(
        backgroundColor: ngPodBg,
        foregroundColor: ngWhite,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: ngH2,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: ngPlayerYellow,
        inactiveTrackColor: ngBlack,
        thumbColor: ngPlayerYellow,
        overlayColor: ngPlayerYellow.withValues(alpha: 0.2),
        trackHeight: 12,
        trackShape: const RectangularSliderTrackShape(),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: ngGold,
        linearTrackColor: ngBlack,
      ),
      dividerTheme: DividerThemeData(color: ngHairline, thickness: 1),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: ngGold,
          shape: const RoundedRectangleBorder(),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(color: ngGold),
        textStyle: TextStyle(
            fontFamily: ngHeaderFont, color: ngInk, fontSize: 11),
      ),
      useMaterial3: true,
    );

// ── Совместимость со старым кодом ────────────────────────────────────────────
// (используются в track_downloader.dart — тоже геттеры, чтобы красились)

Color get cBg => ngBlack;
Color get cSurface => ngPodBg;
Color get cSurface2 => ngRowAlt;
Color get cSurface3 => ngBrown;
Color get cPrimary => ngGold;
Color get cPrimary2 => ngBrownMid;
Color get cAccent => ngOrange;
Color get cPink => ngOrange;
Color get cTextPri => ngWhite;
Color get cTextSec => ngText;
Color get cTextDim => ngDim;
Color get cDivider => ngHairline;
Color get cOnPrimary => ngInk;
