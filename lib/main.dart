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
      child:
          ListenableBuilder(
        listenable: themeCtl,
        builder: (context, _) => MaterialApp(
          title: 'NGMusic',
          scrollBehavior: const NoStretchScrollBehavior(),
          theme: ngTheme,
          themeAnimationDuration: Duration.zero,
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
  late final AnimationController _nav = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 0,
  );

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
    _switch.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();
    final lvm = context.read<LibraryViewModel>();

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
    final railInLandscape = landscape && themeCtl.textured;

    final Widget stack = KeyedSubtree(
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


class NgMiniPlayer extends StatefulWidget {
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

    if (vm.isLoadingTrack && !_load.isAnimating) _load.repeat();
    if (!vm.isLoadingTrack && _load.isAnimating) _load.stop();

    final media = MediaQuery.of(context);
    final landscape = media.size.width > media.size.height;
    final compact = widget.compact;

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

    String fmt(Duration d) =>
        '${d.inMinutes.toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
    final timeLabel = '${fmt(vm.position)} / ${fmt(dur ?? Duration.zero)}';

    Widget bar;
    if (compact && themeCtl.textured) {
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
        top: false,
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            bar,
            if (!compact && !themeCtl.textured)
              SizedBox(
                height: 3,
                width: double.infinity,
                child: vm.isLoadingTrack
                  ? AnimatedBuilder(
                      animation: _load,
                      builder: (context, _) {
                        final t = _load.value;
                        final head = t < 0.6
                            ? Curves.easeOutCubic.transform(t / 0.6)
                            : 1.0;
                        final tail = t < 0.4
                            ? 0.0
                            : Curves.easeInCubic.transform((t - 0.4) / 0.6);
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
