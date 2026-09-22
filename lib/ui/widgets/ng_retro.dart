import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/ng_theme.dart';

/// Виджеты, повторяющие вёрстку Newgrounds 2015.
///
/// Соответствие CSS → Flutter:
///   #main>div.fatcol>div  → [NgPod]
///   div.podtop            → [NgPodTop]
///   div.podbot            → рисуется внутри [NgPod]
///   table.audiolist tr    → [NgListRow] / [NgAudioRow]
///   div.podtop div a      → [NgPlateLink]
///   button                → [NgButton]
///   hr                    → [NgHr]
///   .ngp-seek             → [NgStripedBar]

// ── Под ───────────────────────────────────────────────────────────────────────

/// Блок контента 2015: рамка 4px, текстурная шапка, полоска-донышко.
class NgPod extends StatelessWidget {
  /// Имя иконки из спрайта `h2-all.png` (см. [NgTex.h2]), например `audio`.
  final String? icon;
  final String? title;

  /// Правый угол шапки — обычно [NgPlateLink] («More New Audio »»).
  final Widget? action;
  final Widget child;
  final NgSkin skin;

  /// `.podcontent { padding: 21px 11px 11px 11px }`, но списки живут без отступов.
  final EdgeInsets padding;
  final EdgeInsets margin;

  /// Под растягивается на всю доступную высоту, а контент скроллится внутри —
  /// шапка пода остаётся на месте (единственная уступка мобильной сетке).
  final bool fill;

  const NgPod({
    super.key,
    this.icon,
    this.title,
    this.action,
    this.skin = NgSkin.gold,
    this.padding = const EdgeInsets.fromLTRB(11, 15, 11, 11),
    this.margin = const EdgeInsets.only(bottom: 10),
    required this.child,
  }) : fill = false;

  /// Вариант для таблиц: контент без внутренних отступов.
  const NgPod.list({
    super.key,
    this.icon,
    this.title,
    this.action,
    this.skin = NgSkin.gold,
    this.margin = const EdgeInsets.only(bottom: 10),
    required this.child,
  })  : padding = EdgeInsets.zero,
        fill = false;

  /// Под на всю высоту экрана со скроллящимся списком внутри.
  const NgPod.fill({
    super.key,
    this.icon,
    this.title,
    this.action,
    this.skin = NgSkin.gold,
    this.margin = EdgeInsets.zero,
    required this.child,
  })  : padding = EdgeInsets.zero,
        fill = true;

  @override
  Widget build(BuildContext context) {
    final hasHead = title != null;
    final content = Padding(padding: padding, child: child);
    if (themeCtl.textured) {
      // 2015: рамка 4px, текстурное тело, донышко podbot.
      // (Бисект-хак «&& false» из охоты на чёрный экран удалён —
      // причина была в Competing ParentDataWidgets, не в текстурах.)
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          color: ngPodBg,
          border: Border.fromBorderSide(
              BorderSide(color: ngPodBorder, width: 4)),
          borderRadius: const BorderRadius.all(Radius.circular(2)),
          image: const DecorationImage(
            image: AssetImage(NgTex.podBody),
            repeat: ImageRepeat.repeat,
            alignment: Alignment.topLeft,
            fit: BoxFit.none,
          ),
          boxShadow: [
            BoxShadow(color: ngBlack, blurRadius: 10, offset: Offset(0, 5))
          ],
        ),
        child: Column(
          mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasHead)
              NgPodTop(icon: icon, title: title!, action: action, skin: skin),
            if (hasHead) const NgPodBreaker(),
            if (fill) Expanded(child: content) else content,
            const _PodBot(),
          ],
        ),
      );
    }
    // 2024: pod — плоский тёмный корпус, скругление 4px, тонкая рамка.
    return Container(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: ngPodBg,
        border:
            Border.fromBorderSide(BorderSide(color: ngPodBorder, width: 1)),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (hasHead)
            NgPodTop(icon: icon, title: title!, action: action, skin: skin),
          if (fill) Expanded(child: content) else content,
        ],
      ),
    );
  }
}

/// `div.pod-head` 2024: 35px, градиентная планка
/// (rgb(78,87,94) → rgb(52,57,61) → rgb(40,43,48) → rgb(32,36,39)),
/// иконка-квадратик 29×29 со скруглением 4px на тёмной подложке.
class NgPodTop extends StatelessWidget {
  final String? icon;
  final String title;
  final Widget? action;
  final NgSkin skin;

  const NgPodTop({
    super.key,
    this.icon,
    required this.title,
    this.action,
    this.skin = NgSkin.gold,
  });

  @override
  Widget build(BuildContext context) {
    if (themeCtl.textured) {
      // `div.podtop` 2015 — 41px, текстура прижата влево, правый край
      // дублируется справа (для action-плашки).
      return SizedBox(
        height: 41,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: skin.podtopFill,
                image: DecorationImage(
                  image: AssetImage(skin.podtop),
                  alignment: Alignment.topLeft,
                  fit: BoxFit.none,
                ),
              ),
            ),
            if (action != null)
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: skin.podtopFill,
                    image: DecorationImage(
                      image: AssetImage(skin.podtop),
                      alignment: Alignment.topRight,
                      fit: BoxFit.none,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 6, right: 3),
                    child: Center(child: action),
                  ),
                ),
              ),
            Positioned(
              left: 7,
              top: 5,
              bottom: 5,
              right: action != null ? 120 : 5,
              child: Row(
                children: [
                  if (icon != null) ...[
                    Image.asset(NgTex.h2(icon!), width: 27, height: 27),
                    const SizedBox(width: 9),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: ngH2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    // `div.pod-head` 2024: 35px, градиентная планка, иконка 29×29.
    return Container(
      height: 35,
      padding: const EdgeInsets.only(right: 2),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0, 0.48, 0.53, 1],
          colors: [
            Color(0xFF4E575E),
            Color(0xFF34393D),
            Color(0xFF282B30),
            Color(0xFF202427),
          ],
        ),
        border: Border(bottom: BorderSide(color: ngBlack)),
      ),
      child: Row(
        children: [
          const SizedBox(width: 5),
          if (icon != null) ...[
            Container(
              width: 29,
              height: 29,
              clipBehavior: Clip.antiAlias,
              decoration: const BoxDecoration(
                color: Color(0x80000000),
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
              child: Center(
                child: Image.asset(NgTex.h2(icon!), width: 25, height: 25),
              ),
            ),
            const SizedBox(width: 5),
          ],
          Expanded(
            child: Text(
              title,
              style: ngH2,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (action != null)
            Padding(
              padding: const EdgeInsets.only(left: 6, right: 3),
              child: Center(child: action),
            ),
        ],
      ),
    );
  }
}

/// Разделитель: в 2015 — градиентный перелом podbreaker (10px),
/// в 2024 — тонкая линия на стыке секций.
class NgPodBreaker extends StatelessWidget {
  const NgPodBreaker({super.key});

  @override
  Widget build(BuildContext context) {
    if (themeCtl.textured) {
      // `div.podcontent { background: podbreaker-33.jpg no-repeat }` — тень.
      return const SizedBox(
        height: 10,
        child: DecoratedBox(
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(NgTex.podbreaker),
              alignment: Alignment.bottomLeft,
              fit: BoxFit.none,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: 1,
      child: DecoratedBox(
        decoration: BoxDecoration(color: ngHairline),
      ),
    );
  }
}

/// `div.podbot { height:6px; border:1px solid #28242c; border-top:0 }` —
/// донышко пода 2015 (в 2024 не рисуется).
class _PodBot extends StatelessWidget {
  const _PodBot();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: ngPodBotBorder),
          right: BorderSide(color: ngPodBotBorder),
          bottom: BorderSide(color: ngPodBotBorder),
        ),
        image: const DecorationImage(
          image: AssetImage(NgTex.podbreaker),
          alignment: Alignment.topLeft,
          fit: BoxFit.none,
        ),
      ),
    );
  }
}

// ── Плашка-ссылка в шапке пода ────────────────────────────────────────────────

/// Плашка-ссылка в шапке пода 2024: скруглённая кнопка 24px с тёмной
/// подложкой и оранжевым текстом (как button в pod-head).
class NgPlateLink extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;

  const NgPlateLink({super.key, required this.label, this.onTap});

  @override
  State<NgPlateLink> createState() => _NgPlateLinkState();
}

class _NgPlateLinkState extends State<NgPlateLink> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    if (themeCtl.textured) {
      // `div.podtop div a` 2015 — полосатая плашка.
      return GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onTap,
        child: Container(
          height: 25,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            image: DecorationImage(
              image: AssetImage(_down ? NgTex.linkPlateHover : NgTex.linkPlate),
              repeat: ImageRepeat.repeatX,
              alignment: Alignment.centerLeft,
              fit: BoxFit.none,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: ngHeaderFont,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: _down ? ngInk : (enabled ? ngGold : ngInk),
            ),
          ),
        ),
      );
    }
    // 2024: скруглённая кнопка 24px с тёмной подложкой.
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onTap,
      child: Container(
        height: 24,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _down ? ngGold : const Color(0x80000000),
          border: Border.all(color: ngBlack),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          widget.label,
          maxLines: 1,
          overflow: TextOverflow.clip,
          style: TextStyle(
            fontFamily: ngHeaderFont,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            height: 1.0,
            color: _down ? ngInk : (enabled ? ngGold : ngDim),
          ),
        ),
      ),
    );
  }
}

// ── Кнопка ────────────────────────────────────────────────────────────────────

/// Кнопка 2024: плоская тёмная с оранжевым текстом и скруглением 4px.
class NgButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final double? width;
  final String? icon;

  const NgButton({
    super.key,
    required this.label,
    this.onPressed,
    this.width,
    this.icon,
  });

  @override
  State<NgButton> createState() => _NgButtonState();
}

class _NgButtonState extends State<NgButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;

    if (themeCtl.textured) {
      // `button` 2015: текстура button-gold.gif, 9-patch.
      final tex = !enabled
          ? NgTex.buttonDisabled
          : (_down ? NgTex.buttonHover : NgTex.buttonNormal);
      return GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapUp: enabled ? (_) => setState(() => _down = false) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTap: widget.onPressed,
        child: Container(
          height: 27,
          width: widget.width,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: ngBlack),
              right: BorderSide(color: ngBlack),
              bottom: BorderSide(color: ngBlack, width: 2),
            ),
            // 9-patch: края фиксированы, середина тянется.
            image: DecorationImage(
              image: AssetImage(tex),
              centerSlice: const Rect.fromLTRB(6, 6, 60, 19),
              fit: BoxFit.fill,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Image.asset(NgTex.a15(widget.icon!, dark: _down),
                      width: 15, height: 15),
                  const SizedBox(width: 5),
                ],
                Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: ngHeaderFont,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: enabled ? (_down ? ngInk : ngGold) : ngDim,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 2024: плоская тёмная с оранжевым текстом и скруглением 4px.
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: widget.onPressed,
      child: Container(
        height: 28,
        width: widget.width,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: enabled
              ? (_down ? ngGold : const Color(0xFF34393D))
              : const Color(0xFF1A1A1A),
          border: Border.all(color: ngBlack, width: 2),
          borderRadius: const BorderRadius.all(Radius.circular(4)),
        ),
        alignment: Alignment.center,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Image.asset(NgTex.a15(widget.icon!, dark: _down),
                    width: 15, height: 15),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: ngHeaderFont,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  height: 1.0,
                  color: !enabled ? ngDim : (_down ? ngInk : ngGold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NgIconButton extends StatefulWidget {
  final String icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final double padding;

  const NgIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.tooltip,
    this.padding = 6,
  });

  @override
  State<NgIconButton> createState() => _NgIconButtonState();
}

class _NgIconButtonState extends State<NgIconButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    Widget img = Container(
      padding: EdgeInsets.all(widget.padding),
      color: _down ? ngGold : Colors.transparent,
      child: Opacity(
        opacity: widget.onTap == null ? 0.35 : 1,
        child: Image.asset(NgTex.a15(widget.icon, dark: _down),
            width: 15, height: 15),
      ),
    );
    if (widget.tooltip != null) {
      img = Tooltip(message: widget.tooltip!, child: img);
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:
          widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapUp:
          widget.onTap == null ? null : (_) => setState(() => _down = false),
      onTapCancel:
          widget.onTap == null ? null : () => setState(() => _down = false),
      onTap: widget.onTap,
      child: img,
    );
  }
}

// ── Строки списка ─────────────────────────────────────────────────────────────

/// `table.audiolist tr` / `tr.alt` — чередование фона по индексу.
class NgListRow extends StatelessWidget {
  final int index;
  final Widget child;
  final VoidCallback? onTap;
  final NgSkin skin;
  final bool highlight;

  const NgListRow({
    super.key,
    required this.index,
    required this.child,
    this.onTap,
    this.skin = NgSkin.gold,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    final bg = highlight
        ? skin.podtopFill
        : (index.isOdd ? skin.rowAlt : Colors.transparent);
    return Material(
      color: bg,
      child: InkWell(
        onTap: onTap,
        splashColor: skin.podtopFill,
        highlightColor: skin.rowAlt,
        child: child,
      ),
    );
  }
}

/// Строка `a.item-audiosubmission` 2024: иконка 60×60 с PLAY-оверлеем,
/// заголовок + «by Автор» в одну строку, описание, справа — звёзды
/// (star-score-2.webp) и мета-колонка «Song / Жанр / N Views» с тонкой
/// левой границей.
class NgAudioRow extends StatelessWidget {
  final int index;
  final String iconUrl;
  final String title;
  final String genre;
  final String artist;
  final VoidCallback? onTap;
  final VoidCallback? onArtistTap;
  final Widget? trailing;

  /// Текущий трек (подсветка строки).
  final bool playing;

  /// Текущий трек на паузе: оверлей показывает play без затемнения.
  final bool paused;
  final NgSkin skin;

  const NgAudioRow({
    super.key,
    required this.index,
    required this.iconUrl,
    required this.title,
    required this.genre,
    required this.artist,
    this.onTap,
    this.onArtistTap,
    this.trailing,
    this.playing = false,
    this.paused = false,
    this.skin = NgSkin.gold,
  });

  @override
  Widget build(BuildContext context) {
    if (themeCtl.textured) {
      // 2015: квадратная иконка 39×39, название золотым, жанр и автор
      // колонкой (как `table.audiolist`).
      return NgListRow(
        index: index,
        onTap: onTap,
        skin: skin,
        highlight: playing,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 5),
          child: Row(
            children: [
              NgTrackIcon(url: iconUrl, size: 39),
              const SizedBox(width: 7),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style:
                          playing ? ngLink.copyWith(color: ngWhite) : ngLink,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (artist.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: GestureDetector(
                          onTap: onArtistTap,
                          child: Text.rich(
                            TextSpan(
                              style: ngLabel,
                              children: [
                                const TextSpan(text: 'by '),
                                TextSpan(text: artist, style: ngLink),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    if (genre.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(genre,
                            style: ngLabel.copyWith(color: ngText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      );
    }

    // 2024: иконка-диск 60×60 с PLAY-оверлеем, мета-колонка справа.
    return NgListRow(
      index: index,
      onTap: onTap,
      skin: skin,
      highlight: playing,
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            // Иконка-диск 60×60, оверлей внутри круглой обрезки.
            SizedBox(
              width: 60,
              height: 60,
              child: ClipOval(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: NgTrackIcon(url: iconUrl, size: 60, oval: false),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      child: _PlayOverlay(state: playing
                          ? (paused ? _PlayState.paused : _PlayState.playing)
                          : _PlayState.idle),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: playing
                        ? ngLink.copyWith(color: ngWhite)
                        : ngLink.copyWith(
                            fontSize: 14, fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (artist.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: GestureDetector(
                        onTap: onArtistTap,
                        child: Text.rich(
                          TextSpan(
                            style: TextStyle(
                                fontFamily: ngHeaderFont,
                                fontSize: 13,
                                color: ngText),
                            children: [
                              const TextSpan(text: 'by '),
                              TextSpan(
                                text: artist,
                                style: TextStyle(
                                  fontFamily: ngHeaderFont,
                                  fontSize: 13,
                                  color: ngText,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  if (genre.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        genre,
                        style: ngLabel.copyWith(color: ngText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
            ),
            // Мета-колонка: звёзды + счётчики, слева тонкая граница.
            Container(
              margin: const EdgeInsets.only(left: 8),
              padding: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: ngDimmer, width: 1),
                ),
              ),
              child: trailing ?? const SizedBox(width: 8),
            ),
          ],
        ),
      ),
    );
  }
}

enum _PlayState { idle, playing, paused }

/// Оверлей плеера на иконке трека (2024): полупрозрачная круглая подложка
/// (обрезается ClipOval родителя) и белый play/pause по центру.
class _PlayOverlay extends StatelessWidget {
  final _PlayState state;
  const _PlayOverlay({required this.state});

  @override
  Widget build(BuildContext context) {
    // Активный трек — затемнённый диск с pause; на паузе — просто play
    // без затемнения; неактивный — полупрозрачная подложка с play.
    final icon = switch (state) {
      _PlayState.playing => Icons.pause,
      _PlayState.paused || _PlayState.idle => Icons.play_arrow,
    };
    final Color? bg = switch (state) {
      _PlayState.playing || _PlayState.idle => const Color(0x73000000),
      _PlayState.paused => null,
    };
    return IgnorePointer(
      child: SizedBox(
        width: 60,
        height: 60,
        child: Container(
          color: bg,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 34,
            color: ngWhite,
            shadows: [Shadow(color: ngBlack, blurRadius: 4)],
          ),
        ),
      ),
    );
  }
}

/// Строка таблицы деталей сабмишена.
class NgInfoItem {
  final String label;
  final String value;

  /// Правый край строки — например [NgStars].
  final Widget? trailing;

  /// Под значением — графика второй строкой (звёзды и т.п.).
  final Widget? below;

  const NgInfoItem(this.label, this.value, {this.trailing, this.below});
}

/// `table.itemdetails` — узкая колонка подписей слева, значение справа,
/// чередование фона строк как в аудиолисте.
class NgInfoTable extends StatelessWidget {
  final List<NgInfoItem> items;
  final NgSkin skin;
  final double labelWidth;

  /// Минимальная высота строки — чтобы рамки не смотрелись плющенными.
  final double rowHeight;

  const NgInfoTable({
    super.key,
    required this.items,
    this.skin = NgSkin.gold,
    this.labelWidth = 74,
    this.rowHeight = 38,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < items.length; i++)
          NgListRow(
            index: i,
            skin: skin,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: rowHeight),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: labelWidth,
                      child: Text(items[i].label, style: ngLabel),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            items[i].value,
                            style:
                                TextStyle(fontSize: 12, color: ngWhite),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (items[i].below != null) ...[
                            const SizedBox(height: 5),
                            items[i].below!,
                          ],
                        ],
                      ),
                    ),
                    if (items[i].trailing != null) items[i].trailing!,
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Колонка страницы ─────────────────────────────────────────────────────

/// `#main { background: url(bg-main.gif) top center repeat-y; padding: 10px 13px }`
/// — серая колонка, на которой стоят поды. Без неё чёрные рамки подов
/// (`border: solid 4px #000`) сливаются с фоном и блоки выглядят оторванными
/// друг от друга.
///
/// Градиент — пиксели из `bg-main.gif` (970×1): темнее по краям, светлее
/// к центру. Именно градиент, а не сама гишка: она шириной под 950px-колонку
/// и на телефоне её пришлось бы резать.
class NgPageColumn extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;

  const NgPageColumn({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(6, 8, 6, 0),
  });

  static const _gradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [
      Color(0xFF454242),
      Color(0xFF302D2D),
      Color(0xFF363333),
      Color(0xFF716C6C),
      Color(0xFF363333),
      Color(0xFF302D2D),
      Color(0xFF454242),
    ],
    stops: [0, 0.006, 0.03, 0.5, 0.97, 0.994, 1],
  );

  @override
  Widget build(BuildContext context) {
    if (!themeCtl.textured) {
      // 2024: фон страницы плоский, без серой колонки.
      return Padding(padding: padding, child: child);
    }
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: _gradient),
      child: Padding(padding: padding, child: child),
    );
  }
}

// ── Награды сабмишена ──────────────────────────────────────────────────────

/// Иконка награды из спрайта `ul-trophies.png`. Ключ — класс `li` со страницы
/// (`frontpage`, `daily1`…`daily5`, `weekly1`…, `monthly1`…, `review`).
/// Смещения взяты из CSS 2015: `.daily1{background-position:4px -30px}` и далее
/// шагом 35px, `.frontpage` — -590px.
class NgTrophyIcon extends StatelessWidget {
  final String kind;
  final double size;

  const NgTrophyIcon({super.key, required this.kind, this.size = 25});

  static const _offsets = {
    'daily1': 30.0,
    'daily2': 65.0,
    'daily3': 100.0,
    'daily4': 135.0,
    'daily5': 170.0,
    'weekly1': 205.0,
    'weekly2': 240.0,
    'weekly3': 275.0,
    'weekly4': 310.0,
    'weekly5': 345.0,
    'monthly1': 380.0,
    'monthly2': 415.0,
    'monthly3': 450.0,
    'monthly4': 485.0,
    'monthly5': 520.0,
    'review': 555.0,
    'frontpage': 590.0,
  };

  static bool knows(String kind) => _offsets.containsKey(kind);

  @override
  Widget build(BuildContext context) {
    // Глиф в спрайте стоит на 5px ниже начала своей ячейки — без этого
    // смещения иконка выглядит прижатой ко дну.
    final offset = (_offsets[kind] ?? _offsets['frontpage']!) + 5;
    final scale = size / 25;
    return SizedBox(
      width: size,
      height: size,
      child: ClipRect(
        child: OverflowBox(
          maxHeight: double.infinity,
          alignment: Alignment.topLeft,
          child: Transform.translate(
            offset: Offset(0, -offset * scale),
            child: Image.asset(
              NgTex.trophies,
              width: size,
              height: 770 * scale,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Обложка трека ─────────────────────────────────────────────────────────────

/// Обложка трека 2024: круглый диск (`item-icon` обрезается по кругу).
/// [oval] — включить круглую обрезку; дефолт без неё — квадрат (2015).
class NgTrackIcon extends StatelessWidget {
  final String url;
  final double size;
  final bool oval;

  const NgTrackIcon({super.key, required this.url, this.size = 39, this.oval = false});

  @override
  Widget build(BuildContext context) {
    // Декодим сразу в целевой размер (×dpr): полноразмерные _full.webp
    // (500×500+) на каждую строку списка — главный тормоз скролла.
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final cachePx = (size * dpr).round();
    final img = Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      cacheWidth: cachePx,
      errorBuilder: (_, __, ___) => Image.asset(
        NgTex.defaultAudioIcon,
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
    if (!oval) {
      return SizedBox(width: size, height: size, child: img);
    }
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(child: img),
    );
  }
}

// ── Разделитель ───────────────────────────────────────────────────────────────

/// `hr { height:2px; background: #000 url(podstripe.gif) }`
class NgHr extends StatelessWidget {
  final EdgeInsets margin;
  const NgHr(
      {super.key, this.margin = const EdgeInsets.symmetric(vertical: 5)});

  @override
  Widget build(BuildContext context) {
    if (themeCtl.textured) {
      // `hr 2015 { height:2px; background: #000 url(podstripe.gif) }`
      return Container(
        height: 2,
        margin: margin,
        decoration: BoxDecoration(
          color: ngBlack,
          image: DecorationImage(
            image: AssetImage(NgTex.podstripe),
            alignment: Alignment.bottomCenter,
            repeat: ImageRepeat.repeatX,
            fit: BoxFit.none,
          ),
        ),
      );
    }
    return Container(
      height: 1,
      margin: margin,
      color: ngHairline,
    );
  }
}

// ── Звёзды рейтинга ───────────────────────────────────────────────────────────

/// Звёзды рейтинга 2024: спрайт `star-score-2.webp` (36×72) — верхняя
/// половина пустая звезда, нижняя залитая; пять клеток по 18px, частичная
/// заливка — обрезкой по ширине, как `div.star-score span { width: 99% }`.
class NgStars extends StatelessWidget {
  /// 0..5
  final double score;
  final double scale;

  const NgStars({super.key, required this.score, this.scale = 1});

  @override
  Widget build(BuildContext context) {
    if (themeCtl.textured) {
      // 2015: `vp-Stars.png` — полоса из 5 звёзд, заливка обрезкой.
      final w = 87.0 * scale;
      final h = 15.0 * scale;
      final frac = (score / 5).clamp(0.0, 1.0);
      return SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            Image.asset(NgTex.starsEmpty, width: w, height: h, fit: BoxFit.fill),
            ClipRect(
              clipper: _WidthClipper(frac),
              child: Image.asset(NgTex.starsFull,
                  width: w, height: h, fit: BoxFit.fill),
            ),
          ],
        ),
      );
    }
    final w = 18.0 * scale;
    final h = 17.0 * scale;
    return SizedBox(
      height: h,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < 5; i++)
            SizedBox(
              width: w,
              height: h,
              child: Stack(
                children: [
                  _StarCell(filled: false, w: w, h: h),
                  // Заливка i-й звезды обрезается по остатку оценки.
                  ClipRect(
                    clipper: _WidthClipper((score - i).clamp(0.0, 1.0)),
                    child: _StarCell(filled: true, w: w, h: h),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Одна звезда из спрайта 36×72: верхняя половина — пустая, нижняя —
/// залитая. Спрайт масштабируется в клетку (w × 2h, обе половины по w×h),
/// окно ClipRect показывает только нужную половину.
class _StarCell extends StatelessWidget {
  final bool filled;
  final double w;
  final double h;

  const _StarCell({required this.filled, required this.w, required this.h});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: w,
      height: h,
      child: ClipRect(
        child: OverflowBox(
          minWidth: 0,
          minHeight: 0,
          maxWidth: w,
          maxHeight: 2 * h,
          // Верхняя половина растянутого спрайта — пустая звезда,
          // нижняя — залитая.
          alignment: filled ? Alignment.bottomLeft : Alignment.topLeft,
          child: Image.asset(
            NgTex.starScore2024,
            width: w,
            height: 2 * h,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

class _WidthClipper extends CustomClipper<Rect> {
  final double frac;
  const _WidthClipper(this.frac);

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width * frac, size.height);

  @override
  bool shouldReclip(_WidthClipper old) => old.frac != frac;
}

// ── Votebar-звёзды (star-select-2) ──────────────────────────────────────

/// Ряд оценки из votebar NG: blam-звезда (Vote 0) + бар 5 звёзд + Стив.
/// Бар — ЕДИНАЯ жестовая область (аналог div.star-bar): пока палец
/// зажат, звёзды до позиции красятся в hover-кадр (светлое кольцо),
/// обрезанный по ширине N×10% — аналог label[value=N]::before из CSS.
/// Отпускание отправляет голос; поставленный голос рисуется золотым.
/// Спрайт star-select-2.webp (150×666 @2x): NG сжимает весь файл в тайл
/// 46.15×204.92, кадры по 41: 0 hover, 1 idle, 2 checked, 3 битая,
/// 4 blam-розовая. Стив — SteveReact4.webp, кадр = голос 0..10.
class NgVoteStars extends StatefulWidget {
  /// Поставленный голос в шкале NG 0..10 (полузвёзды); null — не голосовал.
  final int? voted;
  final bool enabled;

  /// Отправка голоса (0..10) — на отпускании пальца или одиночном тапе.
  final ValueChanged<int> onVote;

  /// Живое превью (0..10) во время зажатия/драга; null — палец убрали.
  final ValueChanged<int?>? onPreview;

  const NgVoteStars({
    super.key,
    this.voted,
    this.enabled = true,
    required this.onVote,
    this.onPreview,
  });

  @override
  State<NgVoteStars> createState() => _NgVoteStarsState();
}

class _NgVoteStarsState extends State<NgVoteStars> {
  static const _starW = 46.15, _starH = 41.0;
  static const _barW = _starW * 5;

  /// Превью во время зажатия/драга (null — палец не на баре).
  int? _drag;

  /// Зажата blam-звезда (превью голоса 0).
  bool _zeroArmed = false;

  /// NG-шкала: label[value=N] накрывает N×10% бара, значит позиция x
  /// принадлежит значению ceil(x/W×10) — как CSS box model сайта.
  /// 0 = весь путь влево (левый край бара); на сайте ноль достижим
  /// только клавиатурой/блам-звездой, у нас — и драгом тоже.
  int _valueAt(double dx) => dx <= 0
      ? 0
      : ((dx / _barW) * 10).ceil().clamp(1, 10);

  void _preview(int? v) {
    setState(() => _drag = v);
    widget.onPreview?.call(v);
  }

  Widget _barLayer(int frame) => Row(
        children: [for (var i = 0; i < 5; i++) _VoteStarTile(frame: frame)],
      );

  /// Слой бара, обрезанный до value/10 ширины и прижатый влево —
  /// аналог label::before с width: N*10% поверх общего фона.
  Widget _clippedLayer(int value, int frame) => Positioned(
        top: 0,
        bottom: 0,
        left: 0,
        width: _barW * value / 10,
        child: ClipRect(
          child: OverflowBox(
            alignment: Alignment.centerLeft,
            minWidth: _barW,
            maxWidth: _barW,
            minHeight: _starH,
            maxHeight: _starH,
            child: _barLayer(frame),
          ),
        ),
      );

  void _submit() {
    final v = _drag;
    _preview(null);
    if (v != null) widget.onVote(v);
  }

  @override
  Widget build(BuildContext context) {
    final voted = widget.voted?.clamp(0, 10) ?? 0;
    final preview = _drag;
    final enabled = widget.enabled;

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(
        height: _starH,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // «0 звёзд» — битая: серая (кадр 3); при зажатии или
            // поставленном голосе 0 — розовая (кадр 4).
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown:
                  enabled ? (_) => setState(() => _zeroArmed = true) : null,
              onTapCancel:
                  enabled ? () => setState(() => _zeroArmed = false) : null,
              onTap: enabled
                  ? () {
                      setState(() => _zeroArmed = false);
                      widget.onVote(0);
                    }
                  : null,
              child: SizedBox(
                width: _starW,
                height: _starH,
                child: Stack(children: [
                  Positioned.fill(child: _VoteStarTile(frame: 3)),
                  if (_zeroArmed ||
                      preview == 0 ||
                      widget.voted == 0 ||
                      (widget.voted != null && voted == 0 && preview == null))
                    Positioned.fill(child: _VoteStarTile(frame: 4)),
                ]),
              ),
            ),
            const SizedBox(width: 2),
            // Бар: одна область на 5 звёзд; фон idle, поверх — голос
            // (золото) и живое превью (кольцо), оба клипом по ширине.
            // Сырые указатели через Listener (вне арены жестов):
            // и стоячий тап, и драг дают одинаковый поток событий,
            // как на сайте — где label ловит и click, и hover.
            Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: enabled
                  ? (e) => _preview(_valueAt(e.localPosition.dx))
                  : null,
              onPointerMove: enabled
                  ? (e) => _preview(_valueAt(e.localPosition.dx))
                  : null,
              onPointerUp: enabled ? (_) => _submit() : null,
              onPointerCancel: enabled ? (_) => _preview(null) : null,
              // Поглощаем вертикальный драг: иначе страница скроллится,
              // пока ведёшь пальцем по звёздам (Listener вне арены и сам
              // её не блокирует). Заглушки нужны именно как распознаватель.
              child: GestureDetector(
                onVerticalDragStart: enabled ? (_) {} : null,
                onVerticalDragUpdate: enabled ? (_) {} : null,
                onVerticalDragEnd: enabled ? (_) {} : null,
                child: SizedBox(
                  width: _barW,
                  height: _starH,
                  child: Stack(children: [
                    Positioned.fill(child: _barLayer(1)), // idle-фон
                    if (voted > 0) _clippedLayer(voted, 2), // checked
                    if (preview != null) _clippedLayer(preview, 0), // hover
                  ]),
                ),
              ),
            ),
            const SizedBox(width: 6),
            // Реакция Стива: кадр = текущее значение (превью главнее).
            _SteveReact(frame: (preview ?? voted).clamp(0, 10)),
          ],
        ),
      ),
    );
  }
}

/// Звезда votebar из star-select-2: весь файл (150×666 @2x) сжимается
/// в тайл 46.15×204.92 (как background-size NG), кадр = 41px по вертикали.
class _VoteStarTile extends StatelessWidget {
  final int frame;
  const _VoteStarTile({required this.frame});

  @override
  Widget build(BuildContext context) {
    return _SpriteCrop(
      asset: NgTex.starSelect2024,
      fileW: 150,
      fileH: 666,
      tileW: 46.15,
      tileH: 204.92,
      sliceY: frame * 41.0,
      frameH: 41,
    );
  }
}

/// Реакция Стива: файл 210×2035 @2x сжат до 45.4×440, кадры по 40 —
/// кадр N (0..10) = y N×40.
class _SteveReact extends StatelessWidget {
  final int frame;
  const _SteveReact({required this.frame});

  @override
  Widget build(BuildContext context) {
    return _SpriteCrop(
      asset: NgTex.steveReact2024,
      fileW: 210,
      fileH: 2035,
      tileW: 45.4054,
      tileH: 440,
      sliceY: frame.clamp(0, 10) * 40.0,
      frameH: 40,
    );
  }
}

/// Вырезка кадра из спрайта с масштабированием файла в CSS-тайл
/// (как background-size у NG): файл fileW×fileH сжат до tileW×tileH,
/// показан кадр высотой frameH с отступом sliceY сверху. Виджет —
/// tileW×frameH.
class _SpriteCrop extends StatelessWidget {
  final String asset;
  final double fileW, fileH;
  final double tileW, tileH;
  final double sliceY;
  final double frameH;

  const _SpriteCrop({
    required this.asset,
    required this.fileW,
    required this.fileH,
    required this.tileW,
    required this.tileH,
    required this.sliceY,
    required this.frameH,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: SizedBox(
        width: tileW,
        height: frameH,
        child: OverflowBox(
          minWidth: 0,
          minHeight: 0,
          maxWidth: tileW,
          maxHeight: tileH,
          // Окно прижато к нужному кадру: -1 = верх тайла, 1 = низ.
          alignment: Alignment(
              0, tileH <= frameH ? 0 : sliceY / (tileH - frameH) * 2 - 1),
          child: Image.asset(
            asset,
            width: tileW,
            height: tileH,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

// ── Полосатый прогресс-бар плеера ─────────────────────────────────────────────

/// `.ngp-seek-fill { repeating-linear-gradient(45deg,#fc0 0,#fc0 8px,#111 8px,#111 16px) }`
class NgStripedBar extends StatelessWidget {
  /// 0..1
  final double value;
  final double height;

  /// Буферизация/загрузка: полоски едут.
  final double phase;

  const NgStripedBar({
    super.key,
    required this.value,
    this.height = 14,
    this.phase = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: ngBlack,
        border: Border.fromBorderSide(BorderSide(color: ngSeekBorder)),
      ),
      child: ClipRect(
        child: CustomPaint(
          painter: _StripePainter(value.clamp(0.0, 1.0), phase),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _StripePainter extends CustomPainter {
  final double value;
  final double phase;
  const _StripePainter(this.value, this.phase);

  static const _band = 8.0; // ширина полосы из CSS

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width * value;
    if (w <= 0) return;
    canvas.clipRect(Rect.fromLTWH(0, 0, w, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, w, size.height), Paint()..color = ngPlayerStripe);

    final paint = Paint()..color = ngPlayerYellow;
    // 45°: смещаем каждую полосу на высоту, получая диагональ
    const step = _band * 2;
    final start = -size.height - (phase % step);
    for (double x = start; x < w + size.height; x += step) {
      final p = Path()
        ..moveTo(x, size.height)
        ..lineTo(x + _band, size.height)
        ..lineTo(x + _band + size.height, 0)
        ..lineTo(x + size.height, 0)
        ..close();
      canvas.drawPath(p, paint);
    }
  }

  @override
  bool shouldRepaint(_StripePainter old) =>
      old.value != value || old.phase != phase;
}

// ── Поле ввода ────────────────────────────────────────────────────────────────

/// `input[type=text]` 2015: светлая золотистая плашка с тёмным текстом.
class NgTextField extends StatelessWidget {
  final TextEditingController controller;
  final String? hint;
  final FocusNode? focusNode;
  final ValueChanged<String>? onSubmitted;
  final ValueChanged<String>? onChanged;
  final bool obscure;
  final Widget? suffix;

  const NgTextField({
    super.key,
    required this.controller,
    this.hint,
    this.focusNode,
    this.onSubmitted,
    this.onChanged,
    this.obscure = false,
    this.suffix,
  });

  @override
  Widget build(BuildContext context) {
    if (!themeCtl.textured) {
      // 2024: тёмное поле rgb(40,43,48) со светлым текстом.
      return Container(
        height: 28,
        decoration: BoxDecoration(
          color: const Color(0xFF282B30),
          border: Border.all(color: ngHairline),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: TextField(
                  controller: controller,
                  focusNode: focusNode,
                  obscureText: obscure,
                  onSubmitted: onSubmitted,
                  onChanged: onChanged,
                  cursorColor: ngGold,
                  cursorWidth: 1,
                  style: TextStyle(
                      fontFamily: ngHeaderFont,
                      color: ngText,
                      fontSize: 13),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: hint,
                    hintStyle: TextStyle(
                        fontFamily: ngHeaderFont,
                        color: ngDim,
                        fontSize: 13),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 5),
                  ),
                ),
              ),
            ),
            if (suffix != null) suffix!,
          ],
        ),
      );
    }
    // 2015: светлая золотистая плашка с тёмным текстом.
    return Container(
      height: 28,
      decoration: BoxDecoration(
        color: Color(0xFFE0C070),
        border: Border.fromBorderSide(BorderSide(color: ngBlack)),
        image: DecorationImage(
          image: AssetImage(NgTex.input),
          repeat: ImageRepeat.repeatX,
          fit: BoxFit.fitHeight,
          alignment: Alignment.centerLeft,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Center(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                obscureText: obscure,
                onSubmitted: onSubmitted,
                onChanged: onChanged,
                cursorColor: ngInk,
                cursorWidth: 1,
                style: const TextStyle(
                    color: Color(0xFF1B1006), fontSize: 12, height: 1.2),
                decoration: InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  hintText: hint,
                  hintStyle: const TextStyle(
                      color: Color(0xFF7A5A20), fontSize: 12, height: 1.2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 5),
                ),
              ),
            ),
          ),
          if (suffix != null) suffix!,
        ],
      ),
    );
  }
}

// ── Серая колонка страницы ────────────────────────────────────────────────────
// ── Пустое состояние / ошибка / загрузка в стиле пода ─────────────────────────

class NgNotice extends StatelessWidget {
  final String text;
  final String? icon;
  final Widget? action;

  const NgNotice({super.key, required this.text, this.icon, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Image.asset(NgTex.h2(icon!), width: 31, height: 31),
            ),
          Text(text, textAlign: TextAlign.center, style: ngBody),
          if (action != null) ...[
            const SizedBox(height: 12),
            action!,
          ],
        ],
      ),
    );
  }
}

// ── Секция-аккордеон внутри пода ──────────────────────────────────────────────

/// `table.audiolist th` в роли заголовка-кнопки: тёмная полоска
/// с подписью группы строк; клик сворачивает содержимое.
///
/// [count] рисуется справа, чтобы было видно размер свёрнутой группы.
class NgSectionHead extends StatelessWidget {
  final String label;
  final String icon;
  final int? count;
  final bool collapsed;
  final VoidCallback? onTap;

  const NgSectionHead({
    super.key,
    required this.label,
    required this.icon,
    this.count,
    this.collapsed = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: ngBlack,
          border: Border(
            top: BorderSide(color: ngHairline),
            bottom: BorderSide(color: ngHairline),
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
        child: Row(
          children: [
            Image.asset(NgTex.h2(icon), width: 15, height: 15),
            const SizedBox(width: 6),
            Text(
              label.toUpperCase(),
              style: ngLabel.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text('($count)', style: ngLabel),
            ],
            const Spacer(),
            if (onTap != null)
              // Спрайтовые collapse/expand на 15×15 неразличимы (один и тот же
              // крестик). Шеврон-стрелка: вправо = свёрнуто, вниз = развёрнуто.
              AnimatedRotation(
                turns: collapsed ? 0 : 0.25,
                duration: const Duration(milliseconds: 150),
                child: Image.asset(
                  NgTex.a15('arrow-right'),
                  width: 15,
                  height: 15,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Группа строк со сворачиваемым заголовком.
class NgSection extends StatelessWidget {
  final String label;
  final String icon;
  final int? count;
  final bool collapsed;
  final VoidCallback? onToggle;
  final List<Widget> children;

  const NgSection({
    super.key,
    required this.label,
    required this.icon,
    required this.children,
    this.count,
    this.collapsed = false,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        NgSectionHead(
          label: label,
          icon: icon,
          count: count,
          collapsed: collapsed,
          onTap: onToggle,
        ),
        // Свёрнутое состояние — пустой второй ребёнок: AnimatedCrossFade
        // держит оба в дереве, но строки не занимают места.
        AnimatedCrossFade(
          duration: const Duration(milliseconds: 180),
          firstCurve: Curves.easeOut,
          secondCurve: Curves.easeOut,
          sizeCurve: Curves.easeOut,
          crossFadeState:
              collapsed ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          firstChild: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
          secondChild: const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}

/// Минималистичный индикатор загрузки: точки вращаются вокруг общего
/// центра (орбита), каждая чуть отстаёт по фазе — классический спиннер.
class NgLoading extends StatefulWidget {
  final double width;

  /// Диаметр орбиты. По умолчанию подбирается от ширины — старые вызовы
  /// с width 100/120/140 дают привычный масштаб.
  final double? size;

  /// Компактный режим для строк/шапок: без вертикального паддинга.
  final bool compact;

  const NgLoading(
      {super.key, this.width = 120, this.size, this.compact = false});

  @override
  State<NgLoading> createState() => _NgLoadingState();
}

class _NgLoadingState extends State<NgLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.size ?? (widget.width / 4).clamp(18.0, 34.0);
    const dots = 5; // 5 точек по кругу
    return Padding(
      padding: EdgeInsets.symmetric(
          vertical: widget.compact ? 0 : 28, horizontal: widget.compact ? 8 : 0),
      child: Center(
        child: SizedBox(
          width: d,
          height: d,
          child: AnimatedBuilder(
            animation: _c,
            builder: (_, __) => CustomPaint(
              painter: _OrbitDotsPainter(
                progress: _c.value,
                dots: dots,
                orbit: d / 2 - d / 10,
                dotRadius: d / 10,
              ),
              size: Size.square(d),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrbitDotsPainter extends CustomPainter {
  final double progress; // 0..1 за цикл
  final int dots;
  final double orbit; // радиус орбиты
  final double dotRadius;

  const _OrbitDotsPainter({
    required this.progress,
    required this.dots,
    required this.orbit,
    required this.dotRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    for (var i = 0; i < dots; i++) {
      final angle = 2 * math.pi * (progress + i / dots);
      final p = Offset(
        center.dx + orbit * math.cos(angle),
        center.dy + orbit * math.sin(angle),
      );
      // Точка ярче, когда она «спереди» (верх полукруга) — глубина вращения.
      final depth = 0.5 - 0.5 * math.sin(angle);
      final paint = Paint()
        ..color = Colors.white.withValues(alpha: 0.25 + 0.75 * depth);
      canvas.drawCircle(p, dotRadius, paint);
    }
  }

  @override
  bool shouldRepaint(_OrbitDotsPainter old) =>
      old.progress != progress || old.orbit != orbit;
}