import 'package:flutter/material.dart';

import '../theme/ng_theme.dart';
import 'ng_retro.dart';



class NgAccent {
  static const orange = Color(0xFFE15F20);
  static const blue = Color(0xFF3A94E0);
  static const red = Color(0xFFF74040);
  static const green = Color(0xFF60B136);
  static const pink = Color(0xFFEB4FA2);
  static const aqua = Color(0xFF26B28C);
  static const purple = Color(0xFFC767E5);
  static const gray = Color(0xFF8698A2);
}

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

class NgLogoBar extends StatelessWidget {
  final String? username;
  final String? avatarUrl;
  final VoidCallback onUserTap;

  final Widget? leading;

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
              cacheWidth: (30 * (MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0)).round(),
              errorBuilder: (_, __, ___) =>
                  Image.asset(NgTex.h2('user'), width: 20, height: 20),
            ),
    );
  }
}

class NgNavPlate extends StatelessWidget {
  final String label;
  final Color accent;
  final bool selected;
  final VoidCallback onTap;

  final double activation;

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
    if (themeCtl.textured) {
      return side ? _plate2015() : Expanded(child: _plate2015());
    }
    final lineAlpha = 0.45 + 0.55 * activation;
    final glowAlpha = 0.32 * activation;
    final textWeight = activation > 0.5 ? FontWeight.w500 : FontWeight.w400;
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
    return side ? plate : Expanded(child: plate);
  }

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

class _NavButton extends StatelessWidget {
  final String icon;
  final String label;
  final Color accent;
  final bool selected;
  final bool last;

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

    final lineAlpha = 0.35 + 0.65 * activation;
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

class NgNavPlates extends StatelessWidget {
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
              activation: (1 - (pos - i).abs()).clamp(0.0, 1.0),
            ),
        ],
      ),
    );
  }
}

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

class NgRailButton extends StatelessWidget {
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
