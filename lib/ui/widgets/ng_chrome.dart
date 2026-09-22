import 'package:flutter/material.dart';

import '../theme/ng_theme.dart';
import 'ng_retro.dart';

/// Шапка и навигация: две дизайн-эпохи (2015 и 2024) в одних виджетах.

/// Шапка и навигация сайта Newgrounds 2015, сжатые под телефон.
///
/// `.sitelinks` (чёрная полоса с поиском) → [NgSearchBar]
/// `.header .navigation` (логотип)        → [NgLogoBar]
/// `.navbar` (плашки порталов)            → [NgNavPlates]

/// Акцентные цвета порталов из `ng_publish.css`
/// (`body.<skin> #footer .navigation dd span { border-color: … }`).
class NgAccent {
  static const orange = Color(0xFFE15F20); // дефолтный (gold) скин
  static const blue = Color(0xFF3A94E0); // games
  static const red = Color(0xFFF74040); // movies
  static const green = Color(0xFF60B136); // audio
  static const pink = Color(0xFFEB4FA2); // art
  static const aqua = Color(0xFF26B28C);
  static const purple = Color(0xFFC767E5);
  static const gray = Color(0xFF8698A2);
}

/// Шапка 2024: логотип слева, поиск по центру, юзер справа — всё в одной
/// строке (в 2024 sitelinks и header слиты). Поиск — тёмное поле
/// (rgb(40,43,48), радиус 4) с круглой лупой.
class NgSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final ValueChanged<String> onSubmit;
  final VoidCallback? onClear;
  final bool searching;

  const NgSearchBar({
    super.key,
    required this.controller,
    required this.onSubmit,
    this.focusNode,
    this.onClear,
    this.searching = false,
  });

  @override
  Widget build(BuildContext context) {
    if (themeCtl.textured) {
      // 2015: чёрная полоса .sitelinks — лупа + золотое поле + кнопка.
      return Container(
        height: 40,
        color: ngBlack,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Image.asset('assets/ng2015/a15/magnifier.png',
                  width: 25, height: 25),
            ),
            Expanded(
              child: NgTextField(
                controller: controller,
                focusNode: focusNode,
                hint: 'Search Audio',
                onSubmitted: onSubmit,
                onChanged: (v) {
                  if (v.isEmpty) onClear?.call();
                },
                suffix: searching
                    ? NgIconButton(
                        icon: 'close',
                        padding: 4,
                        onTap: () {
                          controller.clear();
                          onClear?.call();
                          focusNode?.unfocus();
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 5),
            NgButton(
              label: 'Search',
              width: 66,
              onPressed: () => onSubmit(controller.text),
            ),
          ],
        ),
      );
    }

    // Шапка 2024: логотип слева, поиск по центру, юзер справа — всё в одной
    // строке (в 2024 sitelinks и header слиты). Поиск — тёмное поле
    // (rgb(40,43,48), радиус 4) с круглой лупой.
    return Container(
      height: 40,
      color: ngBlack,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF282B30),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: ngHairline),
              ),
              child: Row(
                children: [
                  Icon(Icons.search, size: 16, color: ngDim),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      onSubmitted: onSubmit,
                      onChanged: (v) {
                        if (v.isEmpty) onClear?.call();
                      },
                      cursorColor: ngGold,
                      style: TextStyle(
                          fontFamily: ngHeaderFont,
                          color: ngText,
                          fontSize: 13),
                      decoration: InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        hintText: 'Search Audio',
                        hintStyle: TextStyle(
                            fontFamily: ngHeaderFont,
                            color: ngDim,
                            fontSize: 13),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                  if (searching)
                    GestureDetector(
                      onTap: () {
                        controller.clear();
                        onClear?.call();
                        focusNode?.unfocus();
                      },
                      child: Icon(Icons.close, size: 16, color: ngDim),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _ChromeButton(
              label: 'Search', onPressed: () => onSubmit(controller.text)),
        ],
      ),
    );
  }
}

/// Кнопка шапки 2024: плоская серо-градиентная плашка с оранжевым текстом
/// (`button { background: linear-gradient(#34393D 60%, #4E575E 70%) }`).
class _ChromeButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _ChromeButton({required this.label, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0, 0.6, 0.7, 1],
            colors: [
              Color(0xFF34393D),
              Color(0xFF34393D),
              Color(0xFF4E575E),
              Color(0xFF4E575E),
            ],
          ),
          border: const Border.fromBorderSide(
              BorderSide(color: Color(0xFF34393D), width: 2)),
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Arial',
            color: ngGold,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

/// Логотип-строка 2024: тоньше (44px), без рамки, юзер справа с аватаром
/// в тёмном кружке.
class NgLogoBar extends StatelessWidget {
  final String? username;
  final String? avatarUrl;
  final VoidCallback onUserTap;

  /// Виджет слева от лого (например, гамбургер в ландшафте).
  final Widget? leading;

  /// Виджет между лого и профилем (например, строка поиска в ландшафте).
  final Widget? middle;

  const NgLogoBar({
    super.key,
    this.username,
    this.avatarUrl,
    required this.onUserTap,
    this.leading,
    this.middle,
  });

  @override
  Widget build(BuildContext context) {
    if (themeCtl.textured) {
      // 2015: логобар 62px с рамкой снизу, лого-маскот слева.
      return Container(
        height: 62,
        decoration: BoxDecoration(
          color: ngBlack,
          border: Border(bottom: BorderSide(color: ngHairline)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          children: [
            Image.asset(NgTex.logo, height: 44, fit: BoxFit.contain),
            if (middle != null) ...[
              const SizedBox(width: 12),
              Expanded(child: middle!),
            ] else
              const Spacer(),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onUserTap,
              child: username == null
                  ? Text('Login / Sign Up',
                      style: TextStyle(
                          fontFamily: ngHeaderFont,
                          color: ngGold,
                          fontSize: 13,
                          fontWeight: FontWeight.bold))
                  : Row(
                      children: [
                        Text(username!,
                            style: TextStyle(
                                fontFamily: ngHeaderFont,
                                color: ngGold,
                                fontSize: 13,
                                fontWeight: FontWeight.bold)),
                        const SizedBox(width: 6),
                        _Avatar(url: avatarUrl),
                      ],
                    ),
            ),
          ],
        ),
      );
    }

    // Логотип-строка 2024: тоньше (44px), без рамки, юзер справа с аватаром
    // в тёмном кружке.
    return Container(
      height: 44,
      color: ngBlack,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 8),
          ],
          // Лого шапки 2024: танк + «NEWGROUNDS AUDIO PORTAL».
          Image.asset(NgTex.logoHeader2024, height: 36, fit: BoxFit.contain),
          if (middle != null) ...[
            const SizedBox(width: 12),
            Expanded(child: middle!),
          ] else
            const Spacer(),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onUserTap,
            child: username == null
                ? Text('Login / Sign Up',
                    style: TextStyle(
                        fontFamily: ngHeaderFont,
                        color: ngGold,
                        fontSize: 13,
                        fontWeight: FontWeight.bold))
                : Row(
                    children: [
                      Text(username!,
                          style: TextStyle(
                              fontFamily: ngHeaderFont,
                              color: ngGold,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(width: 6),
                      _Avatar(url: avatarUrl),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? url;
  const _Avatar({this.url});

  @override
  Widget build(BuildContext context) {
    // Аватарки 2015 — квадратные, в рамке 1px, без скруглений.
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: ngBrown,
        border: Border.fromBorderSide(BorderSide(color: ngGold)),
      ),
      child: url == null || url!.isEmpty
          ? Image.asset(NgTex.h2('user'), width: 20, height: 20)
          : Image.network(
              url!,
              fit: BoxFit.cover,
              // Аватарка 30px — не декодим полноразмерный исходник.
              cacheWidth: (30 * (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0)).round(),
              errorBuilder: (_, __, ___) =>
                  Image.asset(NgTex.h2('user'), width: 20, height: 20),
            ),
    );
  }
}

/// `nav.header-nav-buttons` 2024: плоские пункты навигации, белый текст,
/// цветная полоска 2px снизу у активного. В портале NG 2024 навбар
/// горизонтальный с градиентной подсветкой при наведении.
class NgNavPlate extends StatelessWidget {
  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  /// 0..1 — насколько вкладка «почти активна» (позиция свайпа TabBarView:
  /// 1 — она активна, 0.5 — свайп дошёл до середины до неё, 0 — далеко).
  /// Линия и подсветка интерполируются по нему плавно, без скачка.
  final double activation;

  /// Вертикальный режим (стопка в ландшафте): линия справа, текст слева.
  final bool side;

  const NgNavPlate({
    super.key,
    required this.label,
    required this.accent,
    required this.selected,
    required this.onTap,
    this.activation = 1,
    this.side = false,
  });

  @override
  Widget build(BuildContext context) {
    // Expanded — только в горизонтальном Row навбара: в вертикальной
    // стопке ландшафта (side) родитель — Column с неограниченной высотой,
    // и Expanded там ронял layout всего хаба (чёрный экран Classic).
    if (themeCtl.textured) {
      return side ? _plate2015() : Expanded(child: _plate2015());
    }
    // Альфа линии: 0.45 (далеко) → 1.0 (активна) — плавно по activation.
    final lineAlpha = 0.45 + 0.55 * activation;
    // Подсветка снизу — до 0.32 альфы у активной.
    final glowAlpha = 0.32 * activation;
    final textWeight = activation > 0.5 ? FontWeight.w500 : FontWeight.w400;
    // В side-режиме плашек нельзя использовать Expanded (родитель —
    // SizedBox конечной ширины в колонке, не Row): это давало серый бокс.
    final plate = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: side ? 36 : null,
        alignment: side ? Alignment.centerLeft : Alignment.center,
        decoration: BoxDecoration(
          color: ngBlack,
          border: side
              ? Border(
                  // Вертикальный режим: линия справа у плашки.
                  right: BorderSide(
                    color: accent.withValues(alpha: lineAlpha),
                    width: 2,
                  ),
                )
              : Border(
                  bottom: BorderSide(
                    color: accent.withValues(alpha: lineAlpha),
                    width: 2,
                  ),
                ),
          gradient: glowAlpha > 0.01
              ? LinearGradient(
                  begin:
                      side ? Alignment.centerLeft : Alignment.topCenter,
                  end: side ? Alignment.centerRight : Alignment.bottomCenter,
                  colors: [
                    accent.withValues(alpha: 0.0),
                    accent.withValues(alpha: glowAlpha),
                  ],
                  stops: const [0.66, 1],
                )
              : null,
        ),
        padding: side
            ? const EdgeInsets.only(left: 12, right: 8)
            : const EdgeInsets.only(top: 6, bottom: 8),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: side ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            fontFamily: ngHeaderFont,
            fontSize: 15,
            height: 1.4,
            fontWeight: textWeight,
            color: ngWhite,
            shadows: const [
              Shadow(color: Color(0x80000000), blurRadius: 8),
            ],
          ),
        ),
      ),
    );
    // Expanded только в горизонтальном Row (NgNavPlates) — там он растягивает
    // плашки на равные доли ширины.
    return side ? plate : Expanded(child: plate);
  }

  /// Стеклянная плашка навбара 2015: светлый блик сверху, объёмный градиент
  /// с переломом на 50%, цветная полоса портала (снизу в горизонтали,
  /// справа в вертикальной стопке ландшафта). Тона — замеры спрайта
  /// `navbar2014.jpg`. Подцветка корпуса интерполируется по [activation].
  Widget _plate2015() {
    final t = 0.34 * activation;
    final strip = Color.lerp(
        Color.lerp(accent, ngBlack, 0.45)!, accent, activation)!;

    Color body(Color base) =>
        Color.lerp(base, Color.lerp(accent, ngBlack, 0.4)!, t)!;

    final gloss = Color.lerp(
        const Color(0xFF807C7E), Color.lerp(accent, ngWhite, 0.25)!, t * 0.5)!;

    Widget core = DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: side ? Alignment.centerLeft : Alignment.topCenter,
          end: side ? Alignment.centerRight : Alignment.bottomCenter,
          stops: const [0, 0.5, 0.5, 1],
          colors: [
            body(const Color(0xFF524E50)),
            body(const Color(0xFF3C3B3D)),
            body(const Color(0xFF2C2B2D)),
            body(const Color(0xFF141314)),
          ],
        ),
      ),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(
                fontFamily: ngHeaderFont,
                fontSize: 16,
                height: 1.1,
                color: activation > 0.5 ? ngWhite : ngText,
                shadows: [
                  Shadow(color: ngBlack, offset: Offset(0, 1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (side) {
      // Вертикальная стопка (ландшафт): полоса портала справа.
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 36,
          margin: const EdgeInsets.only(bottom: 2),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: body(const Color(0xFF2A2628))),
              left: BorderSide(color: body(const Color(0xFF2A2628))),
              right: BorderSide(color: strip, width: 4),
              bottom: BorderSide(color: const Color(0xFF06101A)),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 1, color: gloss),
              Expanded(child: core),
              Container(height: 1, color: body(const Color(0xFF2D2B2B))),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(height: 1, color: body(const Color(0xFF2A2628))),
            Container(height: 1, color: gloss),
            Expanded(child: core),
            Container(height: 1, color: body(const Color(0xFF2D2B2B))),
            Container(height: 1, color: const Color(0xFF06101A)),
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(strip, ngWhite, 0.18)!,
                    Color.lerp(strip, ngBlack, 0.35)!,
                    strip,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Плоский пункт нижней навигации 2024: цветная полоска 3px сверху,
/// яркость которой интерполируется по [activation] (0 — далеко,
/// 1 — активная вкладка), как у [NgNavPlate].
class _NavButton extends StatelessWidget {
  final String icon;
  final String label;
  final Color accent;
  final bool selected;
  final bool last;

  /// 0..1 — насколько вкладка «почти активна» (плавное перетекание цвета
  /// полоски и текста при анимированном переключении).
  final double activation;
  final VoidCallback onTap;

  const _NavButton({
    required this.icon,
    required this.label,
    required this.accent,
    required this.selected,
    required this.last,
    required this.activation,
    required this.onTap,
  });

  IconData _iconFor(String name) {
    switch (name) {
      case 'audio':
        return Icons.audio_file;
      case 'list':
        return Icons.queue_music;
      case 'user':
        return Icons.person_outline;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (themeCtl.textured) {
      // Стеклянная кнопка 2015 — тот же корпус, что у плашек навбара:
      // блик сверху, объёмный градиент с переломом, цветная полоса снизу.
      final t = selected ? 0.34 : 0.0;
      final strip = selected
          ? Color.lerp(accent, ngWhite, 0.35)!
          : Color.lerp(ngBlack, accent, 0.55)!;

      Color body(Color base) =>
          Color.lerp(base, Color.lerp(accent, ngBlack, 0.4)!, t)!;

      return Expanded(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            margin: EdgeInsets.only(right: last ? 0 : 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                    height: 1, color: body(const Color(0xFF2A2628))),
                Container(
                  height: 1,
                  color: selected
                      ? Color.lerp(const Color(0xFF807C7E),
                          Color.lerp(accent, ngWhite, 0.25)!, 0.5)
                      : const Color(0xFF807C7E),
                ),
                Expanded(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        stops: const [0, 0.5, 0.5, 1],
                        colors: [
                          body(const Color(0xFF524E50)),
                          body(const Color(0xFF3C3B3D)),
                          body(const Color(0xFF2C2B2D)),
                          body(const Color(0xFF141314)),
                        ],
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Opacity(
                          opacity: selected ? 1 : 0.6,
                          child: Image.asset(NgTex.h2(icon),
                              width: 22, height: 22),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: ngHeaderFont,
                            fontSize: 16,
                            height: 1.1,
                            color: selected ? ngWhite : ngText,
                            shadows: [
                              Shadow(color: ngBlack, offset: Offset(0, 1)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Container(
                    height: 1, color: body(const Color(0xFF2D2B2B))),
                Container(height: 1, color: const Color(0xFF06101A)),
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color.lerp(strip, ngWhite, 0.18)!,
                        Color.lerp(strip, ngBlack, 0.35)!,
                        strip,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Полоска: приглушённая, но видимая всегда; активная — полная яркость.
    final lineAlpha = 0.35 + 0.65 * activation;
    // Фон плавно подливается к активному; текст/иконка — чётко по факту
    // выбора (без lerp: иначе при анимации обе кнопки выглядят «белыми»).
    final bg = Color.lerp(ngBlack, const Color(0xFF19181C), activation)!;
    final contentColor = selected ? ngWhite : ngDim;
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            border: Border(
              top: BorderSide(
                color: accent.withValues(alpha: lineAlpha),
                width: 3,
              ),
              right: BorderSide(
                color: last ? Colors.transparent : ngHairline,
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(_iconFor(icon), size: 20, color: contentColor),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: ngHeaderFont,
                    fontSize: 13,
                    fontWeight:
                        selected ? FontWeight.w500 : FontWeight.normal,
                    color: contentColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Нижняя навигация приложения (2024: плоская).
///
/// Раньше кнопки были почти чёрными (плоский градиент #1a1717→#080606), и над
/// иконками висела тёмная полоса, которая резала глаз. Теперь у каждой кнопки
/// такой же стеклянный корпус, как у плашек навбара ([NgNavPlate]): светлый
/// блик сверху, объёмный градиент и цветная полоса портала снизу. Чёрного
/// поля над кнопками не осталось.
/// Плоская nav-полоса 2024: пункты-плашки в одну строку 34px,
/// без рамок и 3D-эффектов — активный с тонкой градиентной подсветкой.
class NgNavPlates extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onSelect;
  final List<Color>? accents;

  /// Позиция свайпа вкладок (та же шкала, что у TabController.animation:
  /// 0..labels.length−1, дробная в процессе перелистывания). Если задана —
  /// линии и подсветка интерполируются по ней плавно, а не скачком.
  final double? progress;

  static const _accents = [
    NgAccent.orange,
    NgAccent.blue,
    NgAccent.red,
    NgAccent.green,
    NgAccent.pink,
    NgAccent.purple,
  ];

  const NgNavPlates({
    super.key,
    required this.labels,
    required this.index,
    required this.onSelect,
    this.accents,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = accents ?? _accents;
    final pos = progress ?? index.toDouble();
    return Container(
      height: 40,
      color: ngBlack,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            NgNavPlate(
              label: labels[i],
              accent: palette[i % palette.length],
              selected: i == index,
              onTap: () => onSelect(i),
              // Насколько вкладка «активна» при текущем свайпе: 1 — она,
              // 0 — сосед, посередине — 0.5 (плавное перетекание цвета).
              activation: (1 - (pos - i).abs()).clamp(0.0, 1.0),
            ),
        ],
      ),
    );
  }
}

/// Вертикальные плашки вкладок для ландшафта: те же [NgNavPlate], но
/// «стопкой» со сдвигом вправо у каждой следующей (как трапки друг на друге),
/// компактная ширина. Линия — справа у плашки. Активация — по [progress].
class NgNavPlatesSide extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onSelect;
  final List<Color>? accents;
  final double? progress;

  static const _accents = [
    NgAccent.orange,
    NgAccent.blue,
    NgAccent.red,
    NgAccent.green,
    NgAccent.pink,
    NgAccent.purple,
  ];

  const NgNavPlatesSide({
    super.key,
    required this.labels,
    required this.index,
    required this.onSelect,
    this.accents,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = accents ?? _accents;
    final pos = progress ?? index.toDouble();
    // Единая ширина всех плашек — линии справа встают в одну вертикаль.
    return Container(
      width: 150,
      color: ngBlack,
      child: Column(
        children: [
          for (var i = 0; i < labels.length; i++)
            NgNavPlate(
              label: labels[i],
              accent: palette[i % palette.length],
              selected: i == index,
              onTap: () => onSelect(i),
              activation: (1 - (pos - i).abs()).clamp(0.0, 1.0),
              side: true,
            ),
        ],
      ),
    );
  }
}

class NgBottomNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  /// Позиция анимированного переключения (0..length−1, дробная в полёте).
  /// Линии и текст плавно перетекают по цвету между кнопками.
  final double? progress;

  static const _items = [
    ('audio', 'Audio', NgAccent.green),
    ('list', 'Library', NgAccent.blue),
    ('user', 'Account', NgAccent.orange),
  ];

  const NgBottomNav({
    super.key,
    required this.index,
    required this.onSelect,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final pos = progress ?? index.toDouble();
    // В ландшафте панель компактнее по высоте (48 вместо 60).
    final landscape = MediaQuery.of(context).size.width >
        MediaQuery.of(context).size.height;
    final height = landscape ? 48.0 : 60.0;
    return Container(
      color: ngBlack,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < _items.length; i++)
                _NavButton(
                  icon: _items[i].$1,
                  label: _items[i].$2,
                  accent: _items[i].$3,
                  selected: i == index,
                  last: i == _items.length - 1,
                  // Плавное перетекание, как у плашек [NgNavPlate].
                  activation: (1 - (pos - i).abs()).clamp(0.0, 1.0),
                  onTap: () => onSelect(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}


/// Подвал `#footer` был тут раньше (полосатая лента + копирайт с танком).
/// Убран: на телефоне он только ел высоту списка и мешался под плеером.

// ── Вертикальный навигационный рейл (ландшафт, 2015) ─────────────────────────

/// Уголок-стрелка в правом нижнем углу плашки (в спрайте — вырезанный
/// треугольник цвета портала).
class _PlateCorner extends CustomPainter {
  final Color color;
  const _PlateCorner({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PlateCorner old) => old.color != color;
}

/// Кнопка рейла: узкая стеклянная иконка-плашка в стиле навбара 2015
/// (блик, объёмный градиент, стрелка-уголок, полоса портала справа).
/// Без подписи — назначение считывается с иконки.
class NgRailButton extends StatelessWidget {
  /// Имя иконки из спрайта `h2-all.png` (audio/list/user).
  final String icon;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  const NgRailButton({
    super.key,
    required this.icon,
    required this.accent,
    required this.selected,
    required this.onTap,
  });

  IconData _iconFor(String name) {
    switch (name) {
      case 'audio':
        return Icons.audio_file;
      case 'list':
        return Icons.queue_music;
      case 'user':
        return Icons.person_outline;
      default:
        return Icons.circle;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = selected ? 0.34 : 0.0;
    final strip = selected
        ? Color.lerp(accent, ngWhite, 0.35)!
        : Color.lerp(ngBlack, accent, 0.55)!;

    Color body(Color base) =>
        Color.lerp(base, Color.lerp(accent, ngBlack, 0.4)!, t)!;

    final gloss = selected
        ? Color.lerp(
            const Color(0xFF807C7E), Color.lerp(accent, ngWhite, 0.25)!, 0.5)
        : const Color(0xFF807C7E);

    if (themeCtl.textured) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          height: 42,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: body(const Color(0xFF2A2628))),
              left: BorderSide(color: body(const Color(0xFF2A2628))),
              bottom: BorderSide(color: const Color(0xFF06101A)),
              right: BorderSide(color: strip, width: 3),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(height: 1, color: gloss),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Center(
                      child: Opacity(
                        opacity: selected ? 1 : 0.6,
                        child:
                            Image.asset(NgTex.h2(icon), width: 22, height: 22),
                      ),
                    ),
                    Positioned(
                      right: 1,
                      bottom: 1,
                      child: CustomPaint(
                        size: const Size(7, 7),
                        painter: _PlateCorner(color: strip),
                      ),
                    ),
                  ],
                ),
              ),
              Container(height: 1, color: body(const Color(0xFF2D2B2B))),
            ],
          ),
        ),
      );
    }

    // 2024: плоская иконка с полоской слева (на случай ландшафта).
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        height: 44,
        color: selected ? const Color(0xFF19181C) : ngBlack,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 3, color: accent.withValues(alpha: selected ? 1 : 0.35)),
            Expanded(
              child: Icon(_iconFor(icon),
                  size: 22, color: selected ? ngWhite : ngDim),
            ),
          ],
        ),
      ),
    );
  }
}

/// Вертикальный рейл из [NgRailButton] — замена нижней навигации в ландшафте
/// 2015: прикреплён к правому краю, экономит высоту для плеера.
class NgNavRail extends StatelessWidget {
  final int index;
  final ValueChanged<int> onSelect;

  static const _items = [
    ('audio', NgAccent.green),
    ('list', NgAccent.blue),
    ('user', NgAccent.orange),
  ];

  const NgNavRail({
    super.key,
    required this.index,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      color: ngBlack,
      child: SafeArea(
        left: false,
        top: false,
        bottom: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < _items.length; i++)
              NgRailButton(
                icon: _items[i].$1,
                accent: _items[i].$2,
                selected: i == index,
                onTap: () => onSelect(i),
              ),
          ],
        ),
      ),
    );
  }
}
