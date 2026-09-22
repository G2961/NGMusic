import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'player/ng_audio_handler.dart';
import 'ui/screens/hub_screen.dart';
import 'ui/screens/library_screen.dart';
import 'ui/screens/account_screen.dart';
import 'ui/screens/player_screen.dart';
import 'ui/theme/ng_theme.dart';
import 'ui/widgets/ng_chrome.dart';
import 'ui/widgets/ng_player.dart';
import 'ui/widgets/ng_retro.dart';

import 'viewmodel/ng_viewmodel.dart';
import 'viewmodel/library_viewmodel.dart';

/// Материаловский «резиновый» overscroll (StretchingOverscrollIndicator →
/// ImageFiltered) заменён на ClampingScrollBehavior: stretch-эффект — единственная
/// saveLayer-обёртка вокруг всех скроллов и первый подозреваемый в чёрных
/// кадрах на Impeller/Vulkan после смены ориентации.
class NoStretchScrollBehavior extends MaterialScrollBehavior {
  const NoStretchScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const ClampingScrollPhysics();
  }

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Тема должна быть известна до первого кадра — иначе экран 2024 мигнёт
  // перед переключением на классику.
  ThemeController.load().then((_) {
    runApp(NgMusicApp(handler: NgAudioHandler()));
  });
}

class NgMusicApp extends StatelessWidget {
  final NgAudioHandler handler;
  const NgMusicApp({super.key, required this.handler});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NgViewModel(handler)),
        ChangeNotifierProvider(create: (_) => LibraryViewModel()),
      ],
      child: // Смена темы в Settings дергает themeCtl — перестраиваем всё.
          ListenableBuilder(
        listenable: themeCtl,
        builder: (context, _) => MaterialApp(
          title: 'NGMusic',
          // Material 3 stretch-overscroll (ImageFiltered + saveLayer) на
          // Impeller/Vulkan после поворота давал чёрный кадр — убрано.
          scrollBehavior: const NoStretchScrollBehavior(),
          theme: ngTheme,
          // Ключ по теме заставляет ПЕРЕМОНТИРОВАТЬ дерево (не просто
          // перестроить): const-поддеревья внутри экранов иначе скипаются
          // (identical-виджеты), и тема «доезжает» только после поворота.
          home: KeyedSubtree(
            key: ValueKey('shell-${themeCtl.mode.name}'),
            child: const _RootShell(),
          ),
        ),
      ),
    );
  }
}

class _RootShell extends StatefulWidget {
  const _RootShell({super.key});
  @override
  State<_RootShell> createState() => _RootShellState();
}

class _RootShellState extends State<_RootShell>
    with TickerProviderStateMixin {
  /// Корневые вкладки живут в [IndexedStack] — без PageView и его
  /// scroll-позиций. Свайпов между вкладками и так нет (только кнопки),
  /// а пейджер-механика рвалась при повороте: пересадка контроллера между
  /// горизонтальным и вертикальным PageView оставляла свежую позицию без
  /// layout — в ландшафте классики это давало чёрный экран под шапкой.
  late final AnimationController _nav = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 0,
  );

  /// Переход между корневыми вкладками: 0 → 1 за переключение.
  /// Не [ _nav] — тот ведёт подсветку навбара (значение = позиция вкладки
  /// 0..2), а здесь нужна своя шкала 0..1.
  late final AnimationController _switch = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );

  int _idx = 0;
  String? _lastSyncedUser;

  static const _screens = [
    HubScreen(),
    LibraryScreen(),
    AccountScreen(),
  ];

  @override
  void dispose() {
    _nav.dispose();
    _switch.dispose();
    super.dispose();
  }

  void _go(int i) {
    if (i == _idx) return;
    setState(() => _idx = i);
    _nav.animateTo(i.toDouble(), curve: Curves.easeOutCubic);
    // Контент «поднимается»: новый экран въезжает снизу с фейдом
    // (привычный переход 2015). Стек при этом НЕ перемонтируется —
    // состояние вкладок (скроллы, TabController) живёт между switching.
    _switch.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();
    final lvm = context.read<LibraryViewModel>();

    // Sync NG playlists when user logs in
    final user = vm.currentUser;
    if (user != null && user.username != _lastSyncedUser) {
      _lastSyncedUser = user.username;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        lvm.syncNgPlaylists(user.username);
      });
    } else if (user == null && _lastSyncedUser != null) {
      _lastSyncedUser = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        lvm.clearNgPlaylists();
      });
    }

    final landscape = MediaQuery.of(context).size.width > MediaQuery.of(context).size.height;
    // Ландшафт 2015: рейл справа вместо нижней навигации. Шелл разведён
    // по ключу: при повороте обёртка меняется полностью, и GlobalKey
    // внутри экранов не таскает старые рендер-объекты между ветками —
    // иначе Stack оставался со старыми (портретными) размерами и
    // ландшафтная раскладка не досчитывалась (чёрный экран + overflow).
    final railInLandscape = landscape && themeCtl.textured;

    final Widget stack = KeyedSubtree(
      // Ключ только rail/bottom — смена вкладки или темы больше не
      // перемонтирует стек: слетали скроллы и вкладка хаба.
      key: ValueKey('shell-${railInLandscape ? 'rail' : 'bottom'}'),
      child: FadeTransition(
        opacity: CurvedAnimation(parent: _switch, curve: Curves.easeOut),
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: _switch, curve: Curves.easeOutCubic)),
          child: IndexedStack(index: _idx, children: _screens),
        ),
      ),
    );

    if (railInLandscape) {
      return Scaffold(
        backgroundColor: ngBlack,
        body: Row(
          children: [
            Expanded(child: stack),
            NgNavRail(index: _idx, onSelect: _go),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: ngBlack,
      body: stack,
      // Компактный плеер в ландшафте живёт внутри левой панели хаба
      // (см. HubScreen), поэтому здесь — только навбар. В портрете —
      // полоса мини-плеера над навбаром.
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _nav,
            builder: (_, __) {
              return landscape
                  ? NgBottomNav(
                      index: _idx,
                      progress: _nav.value,
                      onSelect: _go,
                    )
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (vm.currentTrack != null) NgMiniPlayer(),
                        NgBottomNav(
                          index: _idx,
                          progress: _nav.value,
                          onSelect: _go,
                        ),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }
}

// ─── Мини-плеер над нижней навигацией ───────────────────────────

/// Мини-плеер 2024: плоская тёмная полоса, транспорт слева, центр —
/// название/автор, справа heart и время; снизу тонкий оранжевый
/// прогресс (вместо полосок 2015). Порядок кнопок прежний.
/// Во время загрузки трека вместо прогресса бежит сегмент-индикатор.
class NgMiniPlayer extends StatefulWidget {
  /// Ультра-компактная вертикальная карточка для левой панели в ландшафте.
  final bool compact;

  const NgMiniPlayer({super.key, this.compact = false});

  @override
  State<NgMiniPlayer> createState() => _NgMiniPlayerState();
}

class _NgMiniPlayerState extends State<NgMiniPlayer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _load;

  @override
  void initState() {
    super.initState();
    // Бегущая полоска загрузки: цикл 700ms, как в 2024-дизайне NG.
    _load = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
  }

  @override
  void dispose() {
    _load.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();
    final track = vm.currentTrack!;
    final dur = vm.duration;
    final progress = (dur != null && dur.inMilliseconds > 0)
        ? (vm.position.inMilliseconds / dur.inMilliseconds).clamp(0.0, 1.0)
        : 0.0;
    final lvm = context.watch<LibraryViewModel>();
    final isFav = lvm.isFavorite(track.id);

    // Тикер бежит только пока трек грузится — батарея не тратится.
    if (vm.isLoadingTrack && !_load.isAnimating) _load.repeat();
    if (!vm.isLoadingTrack && _load.isAnimating) _load.stop();

    final media = MediaQuery.of(context);
    final landscape = media.size.width > media.size.height;
    final compact = widget.compact;

    // ── Транспорт (кнопки) — общие для обеих раскладок.
    final transport = themeCtl.textured
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              NgGlyphButton(
                  glyph: NgGlyph.prev,
                  glyphSize: 16,
                  hitSize: 30,
                  onTap: vm.hasPrev() ? vm.playPrev : null),
              NgGlyphButton(
                glyph: vm.isPlaying ? NgGlyph.pause : NgGlyph.play,
                glyphSize: 20,
                hitSize: 36,
                onTap: vm.isLoadingTrack ? null : vm.togglePlayPause,
              ),
              NgGlyphButton(
                  glyph: NgGlyph.next,
                  glyphSize: 16,
                  hitSize: 30,
                  onTap: vm.hasNext() ? vm.playNext : null),
              GestureDetector(
                onTap: () => lvm.toggleFavorite(track),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    size: 16,
                    color: isFav ? ngRed : ngDim,
                  ),
                ),
              ),
            ],
          )
        : compact
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _miniIcon(Icons.skip_previous, 18,
                  vm.hasPrev() ? vm.playPrev : null),
              _miniIcon(
                  vm.isPlaying ? Icons.pause : Icons.play_arrow,
                  22,
                  vm.isLoadingTrack ? null : vm.togglePlayPause),
              _miniIcon(Icons.skip_next, 18,
                  vm.hasNext() ? vm.playNext : null),
              GestureDetector(
                onTap: () => lvm.toggleFavorite(track),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    size: 16,
                    color: isFav ? ngRed : ngDim,
                  ),
                ),
              ),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.skip_previous, size: 22, color: ngText),
                onPressed: vm.hasPrev() ? vm.playPrev : null,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  vm.isPlaying ? Icons.pause : Icons.play_arrow,
                  size: 26,
                  color: ngWhite,
                ),
                onPressed: vm.isLoadingTrack ? null : vm.togglePlayPause,
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.skip_next, size: 22, color: ngText),
                onPressed: vm.hasNext() ? vm.playNext : null,
              ),
              GestureDetector(
                onTap: () => lvm.toggleFavorite(track),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    isFav ? Icons.favorite : Icons.favorite_border,
                    size: 20,
                    color: isFav ? ngRed : ngDim,
                  ),
                ),
              ),
            ],
          );

    // Тексты таймера «позиция / длительность».
    String fmt(Duration d) =>
        '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    final timeLabel = '${fmt(vm.position)} / ${fmt(dur ?? Duration.zero)}';

    // ── Компактная карточка (левая панель ландшафта): обложка, название,
    // таймер, транспорт — всё в вертикальной стопке по макету.
    Widget bar;
    if (compact && themeCtl.textured) {
      // Мини-.ngp 2015: чёрный корпус с тонкой рамкой, квадратная обложка,
      // золотоё название, полосатый сикбар, глифы транспорта #fc0.
      bar = Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(6, 0, 6, 8),
        decoration: BoxDecoration(
          color: ngBlack,
          border: Border.fromBorderSide(
              BorderSide(color: const Color(0xFF2A2724))),
          borderRadius: BorderRadius.circular(2),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                NgTrackIcon(url: track.aIconUrl, size: 40),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(track.title,
                          style: ngLink,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      Text(track.artist,
                          style: ngLabel.copyWith(color: ngText),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            NgTimeLabel(
                position: vm.position, duration: dur, fontSize: 10),
            const SizedBox(height: 2),
            NgStripedBar(
              value: progress,
              height: 8,
              phase: vm.isLoadingTrack ? _load.value * 16 : 0,
            ),
            const SizedBox(height: 2),
            Center(child: transport),
          ],
        ),
      );
    } else if (compact) {
      bar = Container(
        width: double.infinity,
        margin: const EdgeInsets.fromLTRB(6, 0, 6, 8),
        decoration: BoxDecoration(
          color: ngPodBg,
          border: Border.all(color: ngHairline),
          borderRadius: BorderRadius.circular(6),
        ),
        padding: const EdgeInsets.all(6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                NgTrackIcon(url: track.aIconUrl, size: 40, oval: true),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Таймер — справа сверху, как на макете.
                      Text(timeLabel,
                          style: TextStyle(
                              fontFamily: 'Arial',
                              color: ngDim,
                              fontSize: 9,
                              fontFeatures: [FontFeature.tabularFigures()])),
                      const SizedBox(height: 2),
                      Text(track.title,
                          style: TextStyle(
                              fontFamily: 'Arial',
                              color: ngWhite,
                              fontSize: 12,
                              fontWeight: FontWeight.w500),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      Text(track.artist,
                          style: ngLink.copyWith(fontSize: 10),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Center(child: transport),
          ],
        ),
      );
    } else if (landscape) {
      bar = Container(
        height: 68,
        color: ngPodBg,
        padding: const EdgeInsets.only(left: 6, right: 4),
        child: Row(
          children: [
            NgTrackIcon(url: track.aIconUrl, size: 44, oval: true),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title,
                      style: TextStyle(
                          fontFamily: 'Arial',
                          color: ngWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(track.artist,
                      style: ngLink.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Правый блок: таймер сверху, транспорт под ним.
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(timeLabel,
                    style: TextStyle(
                        fontFamily: 'Arial',
                        color: ngDim,
                        fontSize: 10,
                        fontFeatures: [FontFeature.tabularFigures()])),
                transport,
              ],
            ),
          ],
        ),
      );
    } else {
      // ── Портрет: прежняя полоса 56px.
      bar = themeCtl.textured
          ? Container(
              height: 56,
              decoration: BoxDecoration(
                color: ngBlack,
                border: const Border(
                  top: BorderSide(color: Color(0xFF2A2724)),
                ),
              ),
              padding: const EdgeInsets.only(left: 6, right: 4),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: NgTrackIcon(url: track.aIconUrl, size: 42),
                  ),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.title,
                            style: ngLink,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        Text(track.artist,
                            style: ngLabel.copyWith(color: ngText),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                        const SizedBox(width: 6),
                        transport,
                      ],
                    ),
                  )
                : Container(
                    height: 56,
                    color: ngPodBg,
        padding: const EdgeInsets.only(left: 6, right: 4),
        child: Row(
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: NgTrackIcon(url: track.aIconUrl, size: 42, oval: true),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(track.title,
                      style: TextStyle(
                          fontFamily: 'Arial',
                          color: ngWhite,
                          fontSize: 13,
                          fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(track.artist,
                      style: ngLink.copyWith(fontSize: 12),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 6),
            transport,
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, a, b) => const PlayerScreen(),
          transitionsBuilder: (_, a, b, c) => SlideTransition(
            position: Tween(begin: const Offset(0, 1), end: Offset.zero)
                .animate(
                    CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
            child: c,
          ),
          transitionDuration: const Duration(milliseconds: 350),
        ),
      ),
      child: SafeArea(
        // Только горизонтальные отступы под вырезы/чёлки: вертикальные
        // не нужны (панель и так прижата к низу Scaffold'а).
        top: false,
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            bar,
            // Прогресс — тонкая линия (2024); в компактной карточке не нужна.
            // В 2015 полоса не рисуется: полосатый сикбар живёт внутри бара.
            if (!compact && !themeCtl.textured)
              SizedBox(
                height: 3,
                width: double.infinity,
                child: vm.isLoadingTrack
                  ? AnimatedBuilder(
                      animation: _load,
                      builder: (context, _) {
                        final t = _load.value;
                        // Ведущий край выбегает слева за первые 60% цикла,
                        // хвост догоняет справа — сегмент «протекает» по полосе.
                        final head = t < 0.6
                            ? Curves.easeOutCubic.transform(t / 0.6)
                            : 1.0;
                        final tail = t < 0.4
                            ? 0.0
                            : Curves.easeInCubic.transform((t - 0.4) / 0.6);
                        // Позиция сегмента: центр (head+tail)/2, ширина head-tail;
                        // минимум 4%, чтобы индикатор не исчезал на краях цикла.
                        final width = (head - tail).clamp(0.04, 1.0);
                        final center = (head + tail) / 2;
                        final x = ((center * 2 - 1) / (1 - width))
                            .clamp(-1.0, 1.0);
                        return ColoredBox(
                          color: ngHairline,
                          child: FractionallySizedBox(
                            alignment: Alignment(x, 0),
                            widthFactor: width,
                            child: ColoredBox(color: ngPlayerYellow),
                          ),
                        );
                      },
                    )
                  : LinearProgressIndicator(
                      value: progress,
                      backgroundColor: ngHairline,
                      color: ngPlayerYellow,
                      minHeight: 3,
                    ),
              ),
          ],
        ),
      ),
    );
  }

  /// Компактная транспортная иконка для ультра-компактной карточки.
  Widget _miniIcon(IconData icon, double size, VoidCallback? onPressed) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Icon(icon, size: size, color: onPressed == null ? ngDim : ngText),
      ),
    );
  }
}

