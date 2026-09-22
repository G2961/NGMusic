import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/model/track.dart';
import '../../data/model/ng_review.dart';
import '../../data/repository/ng_auth.dart';
import '../../data/repository/ng_repository.dart';
import '../../services/track_downloader.dart';
import '../../viewmodel/library_viewmodel.dart';
import '../../viewmodel/ng_viewmodel.dart';
import '../theme/ng_theme.dart';
import '../widgets/add_to_playlist_sheet.dart';
import '../widgets/ng_player.dart';
import '../widgets/ng_retro.dart';
import 'artist_screen.dart';
import 'login_screen.dart';

/// Аудио-портал 2015 носил зелёный скин (`body.green`) — поды здесь зелёные.
const _skin = NgSkin.gold;

/// Полноэкранный плеер: блок `.ngp` флеш-плеера 2015 (сцена + бар с транспортом)
/// плюс два пода под ним — статистика трека и автор.
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();
    final track = vm.currentTrack;
    final landscape = MediaQuery.of(context).size.width >
        MediaQuery.of(context).size.height;

    // Верхняя часть страницы. В ландшафте — как старый YouTube:
    // слева плеер, справа сверху блок автора (с подпиской), под ним
    // Credits & Info, под ним награда (Frontpaged) с датой.
    // Вся верхняя секция жёстко вписана в видимую высоту экрана:
    //   экран − статус-бар − шапка 56 − верхний паддинг 8 − зазор 6.
    // Левый плеер тянется на неё всю (обложка добирает остаток), правая
    // колонка при нехватке места равномерно сжимается (FittedBox).
    final playerBlock = _PlayerPod(vm: vm, track: track);
    final creditsBlock = track == null
        ? const NgPod(
            icon: 'audio',
            title: 'Track Info',
            skin: _skin,
            child: NgNotice(text: 'Nothing is playing.', icon: 'audio'),
          )
        : _CreditsPod(track: track);

    final Widget top;
    if (landscape && track != null) {
      // Вся верхняя секция вписана в видимую высоту:
      //   экран − статус-бар − шапка 56 − верхний паддинг 8 − зазор 6.
      // Левому плееру остаётся ровно topH (обложка добирает остаток минус бары),
      // правая колонка при переполнении скроллится — без FittedBox, который
      // пересчитывал масштаб при догрузке данных (блок «прыгал»).
      final m = MediaQuery.of(context);
      final topH =
          (m.size.height - m.padding.top - 56 - 8 - 6).clamp(180.0, m.size.height);
      // Хром пода вокруг сцены зависит от темы: 2015 — рамка 4+4, шапка 41,
      // breaker 10, паддинг 8, podbot 6 = 73; 2024 — шапка 36 + паддинг 8
      // + граница 1 = 45. Сцена = обложка (artHeight) + бары 92 + рамки 2.
      final chrome = themeCtl.textured ? 73 : 45;
      top = SizedBox(
        height: topH,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 5,
              child: _PlayerPod(
                vm: vm,
                track: track,
                artHeight: topH - chrome - 94,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 4,
              child: Column(
                children: [
                  _AuthorPod(track: track),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          creditsBlock,
                          if (track.awards.isNotEmpty) _TrophyPod(track: track),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else {
      top = Column(children: [
        playerBlock,
        if (track != null) ...[const SizedBox(height: 10), _AuthorPod(track: track)],
        if (track != null) creditsBlock,
      ]);
    }

    return Scaffold(
      backgroundColor: ngBlack,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _TopBar(track: track),
            Expanded(
              // Ключ форсирует полный ребилд при смене трека, иначе в дочерних
              // виджетах остаётся старый автор/название.
              key: ValueKey(track?.id),
              // Поды стоят на серой колонке `#main`, иначе их чёрные рамки
              // сливаются с фоном и блоки ломают композицию.
              child: NgPageColumn(
                padding: EdgeInsets.zero,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(6, 8, 6, 24),
                  child: Column(
                    children: [
                      top,
                      if (track != null) ...[
                        // В ландшафте трофей уже в правой колонке, под Credits.
                        if (!(landscape && track.awards.isNotEmpty))
                          if (track.awards.isNotEmpty) _TrophyPod(track: track),
                        if (track.descriptionHtml != null ||
                            track.description != null)
                          _AuthorCommentsPod(
                            icon: 'doc',
                            title: 'Author Comments',
                            html: track.descriptionHtml,
                            fallbackText: track.description,
                          ),
                        _ReviewsPod(track: track),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Диалоги в стиле пода ──────────────────────────────────────────────────────

/// Окно «нужен логин»: под с текстом и двумя кнопками 2015.
Future<void> _requireLogin(
  BuildContext context,
  NgViewModel vm,
  String message,
) async {
  final doLogin = await showDialog<bool>(
    context: context,
    barrierColor: ngBlack.withValues(alpha: 0.72),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: NgPod(
        icon: 'user',
        title: 'Login Required',
        skin: _skin,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(message, style: ngBody),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                NgButton(
                  label: 'Cancel',
                  onPressed: () => Navigator.pop(ctx, false),
                ),
                const SizedBox(width: 8),
                NgButton(
                  label: 'Log In',
                  icon: 'key',
                  onPressed: () => Navigator.pop(ctx, true),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );

  if (doLogin == true && context.mounted) {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    if (context.mounted) await vm.fetchUser();
  }
}

void _showNgSnack(BuildContext context, String text, {bool ok = true}) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(text, style: TextStyle(color: ngWhite, fontSize: 12)),
    backgroundColor: ok ? ngOrange : ngRed,
    behavior: SnackBarBehavior.floating,
    shape: const RoundedRectangleBorder(),
    duration: const Duration(seconds: 2),
  ));
}

// ── Шапка ─────────────────────────────────────────────────────────────────────

class _TopBar extends StatefulWidget {
  final Track? track;
  const _TopBar({this.track});

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  Future<void> _onFavTap(
      BuildContext context, NgViewModel vm, LibraryViewModel lvm) async {
    if (vm.currentUser == null) {
      await _requireLogin(context, vm, 'Log in to save favorites.');
      return;
    }
    final ok = await lvm.toggleFavorite(widget.track!);
    if (!context.mounted || ok) return;
    final error = lvm.lastError;
    lvm.clearError();
    _showNgSnack(context, error ?? 'Failed to save favorite', ok: false);
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;

    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: ngBlack,
        border: Border(bottom: BorderSide(color: ngHairline)),
      ),
      child: Row(
        children: [
          NgIconButton(
            icon: 'collapse',
            padding: 10,
            tooltip: 'Close player',
            onTap: () => Navigator.maybePop(context),
          ),
          // Логотип сайта в самом верху, как в шапке NG
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: Image.asset(NgTex.logo, height: 40, fit: BoxFit.contain),
            ),
          ),
          if (track != null) ...[
            Builder(builder: (ctx) {
              final lvm = ctx.watch<LibraryViewModel>();
              final vm = ctx.watch<NgViewModel>();
              final isFav = lvm.isFavorite(track.id);
              final syncing = lvm.isFavoriteSyncing(track.id);
              return NgIconButton(
                icon: isFav ? 'fav-on' : 'fav-add',
                padding: 9,
                tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
                onTap: syncing ? null : () => _onFavTap(ctx, vm, lvm),
              );
            }),
            NgIconButton(
              icon: 'playlist',
              padding: 9,
              tooltip: 'Add to playlist',
              onTap: () => showAddToPlaylistSheet(context, track),
            ),
            const SizedBox(width: 4),
          ],
        ],
      ),
    );
  }
}

// ── Под плеера ────────────────────────────────────────────────────────────

/// Шапка «иконка + название трека» и плашка «Download this song!» — точно как
/// на `/audio/listen/{id}`; внутри — блок `.ngp`.
class _PlayerPod extends StatefulWidget {
  final NgViewModel vm;
  final Track? track;

  /// Ландшафт: точная высота обложки (остаток высоты сцены минус бары).
  final double? artHeight;
  const _PlayerPod({required this.vm, this.track, this.artHeight});

  @override
  State<_PlayerPod> createState() => _PlayerPodState();
}

class _PlayerPodState extends State<_PlayerPod> {
  bool _downloading = false;

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    return NgPod(
      icon: 'audio',
      title: track?.title ?? 'Audio Player',
      skin: _skin,
      padding: const EdgeInsets.all(4),
      // В ландшафте (artHeight задан) под сидит в SizedBox(height: topH)
      // впритык: дефолтный нижний margin 10 давал ровно на них overflow.
      margin: widget.artHeight != null
          ? EdgeInsets.zero
          : const EdgeInsets.only(bottom: 10),
      action: track == null
          ? null
          : NgPlateLink(
              label: _downloading ? 'Downloading…' : 'Download »',
              onTap: _downloading
                  ? null
                  : () async {
                      setState(() => _downloading = true);
                      await TrackDownloader.download(track, context);
                      if (mounted) setState(() => _downloading = false);
                    },
            ),
      child: _PlayerStage(vm: widget.vm, track: track, artHeight: widget.artHeight),
    );
  }
}

// ── Блок `.ngp` ──────────────────────────────────────────────────────────────

/// Связывает [NgPlayerStage] с вьюмоделью — сама сцена о ней не знает.
class _PlayerStage extends StatelessWidget {
  final NgViewModel vm;
  final Track? track;
  final double? artHeight;
  const _PlayerStage({required this.vm, this.track, this.artHeight});

  @override
  Widget build(BuildContext context) {
    final duration = vm.duration ??
        ((track?.duration ?? 0) > 0
            ? Duration(seconds: track!.duration)
            : null);

    return NgPlayerStage(
      artUrls: track?.artworkUrls ?? const [],
      artHeight: artHeight,
      playing: vm.isPlaying,
      loading: vm.isLoadingTrack,
      position: vm.position,
      duration: duration,
      shuffle: vm.shuffle,
      repeat: vm.repeat,
      onPlayPause: track == null ? null : vm.togglePlayPause,
      onPrev: vm.hasPrev() ? vm.playPrev : null,
      onNext: vm.hasNext() ? vm.playNext : null,
      onShuffle: vm.toggleShuffle,
      onRepeat: vm.cycleRepeat,
      onSeek: vm.seekTo,
    );
  }
}

// ── Секция деталей: жанр, теги, прослушивания, звёзды, шаринг ───────────────

/// `div.contentdata` со страницы трека: слева жанр и теги, справа
/// «N Plays | N Downloads», ниже звёзды и кнопки шаринга. Цифра оценки
/// здесь не дублируется — она выше, в строке `Score`.
///
/// Живёт вторым `podcontent` внутри пода Credits & Info.
class _DetailsSection extends StatelessWidget {
  final Track track;
  const _DetailsSection({required this.track});

  @override
  Widget build(BuildContext context) {
    final score = double.tryParse(track.score ?? '') ?? 0;
    final stats = [
      if (track.listens != null) '${track.listens} Plays',
      if (track.downloads != null) '${track.downloads} Downloads',
    ].join('  |  ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  track.genre.isEmpty ? 'Unknown Genre' : track.genre,
                  style: ngLink.copyWith(fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (stats.isNotEmpty)
                Text(stats, style: ngLabel.copyWith(color: ngText)),
            ],
          ),
          const SizedBox(height: 3),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tags: ', style: ngLabel),
              Expanded(
                child: track.tags.isEmpty
                    ? Text('None', style: ngLabel)
                    : Text(
                        track.tags.join(', '),
                        style: ngLink.copyWith(fontWeight: FontWeight.normal),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
              ),
            ],
          ),
          const NgHr(margin: EdgeInsets.symmetric(vertical: 6)),
          Row(
            children: [
              if (track.votesPending != null)
                Text(
                  'Waiting for ${track.votesPending} more '
                  'vote${track.votesPending == 1 ? '' : 's'}',
                  style: ngLabel,
                )
              else if (score > 0)
                NgStars(score: score)
              else
                Text('Not rated yet', style: ngLabel),
              const Spacer(),
              _ShareButton(
                letter: 'f',
                color: const Color(0xFF3B5998),
                tooltip: 'Share on Facebook',
                url: 'https://www.facebook.com/sharer/sharer.php'
                    '?u=${Uri.encodeComponent(_trackUrl(track))}',
              ),
              const SizedBox(width: 5),
              _ShareButton(
                letter: 't',
                color: const Color(0xFF55ACEE),
                tooltip: 'Share on Twitter',
                url: 'https://twitter.com/intent/tweet'
                    '?url=${Uri.encodeComponent(_trackUrl(track))}'
                    '&text=${Uri.encodeComponent('${track.title} by ${track.artist}')}',
              ),
              const SizedBox(width: 5),
              NgIconButton(
                icon: 'link',
                padding: 5,
                tooltip: 'Open on Newgrounds',
                onTap: () => _open(_trackUrl(track)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _trackUrl(Track t) => 'https://www.newgrounds.com/audio/listen/${t.id}';

Future<void> _open(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

/// Квадратная кнопка шаринга, как в футере сабмишена 2015.
class _ShareButton extends StatelessWidget {
  final String letter;
  final Color color;
  final String url;
  final String tooltip;

  const _ShareButton({
    required this.letter,
    required this.color,
    required this.url,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: () => _open(url),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: ngBlack),
          ),
          alignment: Alignment.center,
          child: Text(
            letter,
            style: TextStyle(
              color: ngWhite,
              fontSize: 15,
              fontWeight: FontWeight.bold,
              height: 1,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Награды (Frontpaged и прочие трофеи) ──────────────────────────────────────

/// Как на странице 2015: иконка из спрайта `ul-trophies.png`, рядом название
/// награды и дата. Одна награда — под без шапки, несколько — под «Trophies»
/// со списком; в обоих случаях коробка закрывается снизу донышком пода.
class _TrophyPod extends StatelessWidget {
  final Track track;
  const _TrophyPod({required this.track});

  @override
  Widget build(BuildContext context) {
    final rows = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < track.awards.length; i++)
          Padding(
            padding:
                EdgeInsets.only(bottom: i == track.awards.length - 1 ? 0 : 8),
            child: _TrophyRow(award: track.awards[i]),
          ),
      ],
    );

    // Один трофей — без зелёной шапки, как в макете.
    if (track.awards.length == 1) {
      return NgPod(
        skin: _skin,
        padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
        child: rows,
      );
    }

    return NgPod(
      icon: 'badge',
      title: 'Trophies',
      skin: _skin,
      padding: const EdgeInsets.fromLTRB(9, 8, 9, 8),
      child: rows,
    );
  }
}

class _TrophyRow extends StatelessWidget {
  final TrackAward award;
  const _TrophyRow({required this.award});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        NgTrophyIcon(kind: award.kind, size: 22),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                award.label,
                style: TextStyle(
                  fontSize: 13,
                  color: ngWhite,
                  fontWeight: FontWeight.bold,
                  height: 1.15,
                ),
              ),
              if (award.date.isNotEmpty)
                Text(award.date, style: ngLink.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Author Comments: рендер HTML из `#author_comments` ──────────

/// Публичная обёртка для тестов: проверяет пустые строки и схлопывание
/// `p>br` без поднятия приватности `_AuthorCommentsPod`.
class AuthorCommentsTestable extends StatelessWidget {
  final String html;
  const AuthorCommentsTestable({super.key, required this.html});

  @override
  Widget build(BuildContext context) => _AuthorCommentsPod(
        icon: 'doc',
        title: 'Author Comments',
        html: html,
      );
}

/// Максимум ширины картинки в комментах; на узких экранах сжимается
/// под реальную ширину пода.
const _acWidth = 640.0;

/// Лимит высоты картинки, чтобы огромные арты не съедали весь экран.
const _acMaxImgH = 340.0;

/// Авторские комменты: NG отдаёт их как HTML (`p`, `br`, `b`/`strong`,
/// `i`/`em`, `u`, `a`, `blockquote`, `ul`/`ol`, `pre`, `img`). Рендерим
/// подмножество тегов в стиле сайта: абзацы с отступом, цитата — бокс,
/// картинки по прямой ссылке с img.ngfiles.com. Если HTML пуст или не
/// разобрался — плоский текст, как раньше.
class _AuthorCommentsPod extends StatefulWidget {
  final String icon;
  final String title;

  /// Сырой HTML из `#author_comments`; null/пустой → плоский текст.
  final String? html;

  /// Плоский фоллбэк (старое поведение).
  final String? fallbackText;

  const _AuthorCommentsPod({
    required this.icon,
    required this.title,
    this.html,
    this.fallbackText,
  });

  @override
  State<_AuthorCommentsPod> createState() => _AuthorCommentsPodState();
}

class _AuthorCommentsPodState extends State<_AuthorCommentsPod> {
  /// Отступ после абзаца — минимальный зазор между соседними `p`.
  static const _gap = 2.0;

  /// Пустая строка между абзацами (NG больше одной не даёт набрать).
  static const _blankLine = 18.0;

  /// Собранные ссылки: индекс span-а в общем списке → URL.
  final _links = <String>[];

  List<Widget>? _blocks;

  @override
  void initState() {
    super.initState();
    _buildBlocks();
  }

  @override
  void didUpdateWidget(_AuthorCommentsPod old) {
    super.didUpdateWidget(old);
    if (old.html != widget.html || old.fallbackText != widget.fallbackText) {
      _buildBlocks();
    }
  }

  void _buildBlocks() {
    _links.clear();
    _blocks = null;
    final raw = widget.html;
    if (raw != null && raw.trim().isNotEmpty) {
      try {
        final fragment = html_parser.parseFragment(raw);
        final blocks = _acBlocks(fragment.nodes);
        if (blocks.isNotEmpty) _blocks = blocks;
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content = _blocks != null
        ? Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: _blocks!)
        : Text(widget.fallbackText ?? '',
            style: ngBody.copyWith(height: 1.45));

    return NgPod(
      icon: widget.icon,
      title: widget.title,
      skin: _skin,
      child: content,
    );
  }

  /// Разбивает узлы верхнего уровня на блоки: абзацы, цитаты, списки,
  /// картинки. Одиночные инлайн-узлы собираются в один абзац.
  /// Пустой абзац (`p` c одними `br`/пробелами) — ровно одна пустая
  /// строка, повторные схлопываются (как в браузере).
  List<Widget> _acBlocks(List<dom.Node> nodes) {
    final out = <Widget>[];
    final inline = <dom.Node>[];
    var lastBlank = false;

    void addBlank() {
      if (out.isNotEmpty && !lastBlank) {
        out.add(const SizedBox(height: _blankLine));
        lastBlank = true;
      }
    }

    void flush() {
      if (inline.isEmpty) return;
      final txt = _inlinePlainText(inline).trim();
      if (txt.isNotEmpty) {
        final span = _acInline(inline);
        if (span != null) {
          out.add(_acPara(span));
          lastBlank = false;
        }
      } else if (inline.any((n) => n is dom.Element)) {
        // Пробельный мусор между тегами — не пустая строка, а вот
        // `br`-набор — да (внутри абзаца или между блоками).
        addBlank();
      }
      inline.clear();
    }

    for (final n in nodes) {
      if (n is dom.Text) {
        inline.add(n);
      } else if (n is dom.Element) {
        switch (n.localName) {
          case 'script' || 'style' || 'noscript':
            break; // мусор выбрасываем
          case 'p':
            flush();
            final subs = _acParaWithImages(n);
            if (subs.isEmpty) {
              addBlank(); // `<p><br/></p>` — пустая строка
            } else {
              out.addAll(subs);
              lastBlank = false;
            }
          case 'img':
            final img = _acImage(n);
            if (img != null) {
              flush();
              out.add(img);
              lastBlank = false;
            }
          case 'blockquote':
            flush();
            out.add(_acQuote(n));
            lastBlank = false;
          case 'ul' || 'ol':
            flush();
            out.add(_acList(n));
            lastBlank = false;
          case 'pre':
            flush();
            final t = n.text.trim();
            if (t.isNotEmpty) {
              out.add(Padding(
                padding: const EdgeInsets.only(bottom: _gap),
                child: Text(t,
                    style: ngBody.copyWith(height: 1.35, fontSize: 12)),
              ));
              lastBlank = false;
            }
          default:
            inline.add(n);
        }
      }
    }
    flush();
    // Пустая строка в самом конце не нужна.
    if (out.isNotEmpty && out.last is SizedBox) out.removeLast();
    return out;
  }

  /// Абзац с возможными картинками внутри: изображения рвут текст
  /// в отдельные блоки (в TextSpan их положить нельзя). Пустой абзац
  /// (одни `br`) даёт пустой список — пустую строку ставит `_acBlocks`.
  List<Widget> _acParaWithImages(dom.Element el) {
    final out = <Widget>[];
    final inline = <dom.Node>[];
    void flush() {
      if (inline.isEmpty) return;
      if (_inlinePlainText(inline).trim().isNotEmpty) {
        final span = _acInline(inline);
        if (span != null) out.add(_acPara(span));
      }
      inline.clear();
    }

    for (final n in el.nodes) {
      if (n is dom.Element && n.localName == 'img') {
        final img = _acImage(n);
        if (img != null) {
          flush();
          out.add(img);
        }
      } else {
        inline.add(n);
      }
    }
    flush();
    return out;
  }

  /// Плоский текст узлов (для проверки «абзац пустой?»): `br` — как
  /// контент, остальное — рекурсивно текст детей.
  String _inlinePlainText(List<dom.Node> nodes) {
    final buf = StringBuffer();
    for (final n in nodes) {
      if (n is dom.Text) {
        buf.write(n.text);
      } else if (n is dom.Element) {
        if (n.localName == 'br') {
          buf.write('\n');
        } else if (n.localName != 'img') {
          buf.write(_inlinePlainText(n.nodes));
        }
      }
    }
    return buf.toString();
  }

  Widget _acPara(InlineSpan span) => Padding(
        padding: const EdgeInsets.only(bottom: _gap),
        child: Text.rich(span, style: ngBody.copyWith(height: 1.45)),
      );

  Widget _acQuote(dom.Element el) => Container(
        margin: const EdgeInsets.only(bottom: _gap, left: 2),
        padding: const EdgeInsets.fromLTRB(9, 7, 9, 3),
        decoration: BoxDecoration(
          color: const Color(0xFF14110E),
          border: Border.fromBorderSide(BorderSide(color: ngHairline)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: _acBlocks(el.nodes),
        ),
      );

  Widget _acList(dom.Element el) {
    final ordered = el.localName == 'ol';
    final items = <Widget>[];
    var i = 1;
    for (final li in el.children.where((e) => e.localName == 'li')) {
      final span = _acInline(li.nodes);
      if (span == null) continue;
      items.add(Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
                text: ordered ? '${i++}. ' : '•  ',
                style: ngBody.copyWith(color: ngDim)),
            span,
          ]),
          style: ngBody.copyWith(height: 1.4),
        ),
      ));
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: _gap, left: 6),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: items),
    );
  }

  /// Картинка в комментах: только img.ngfiles.com (обложки и рисунки
  /// автора). Пропорции — из width/height или data-smart-scale="W,H"
  /// (NG кладёт туда исходник), иначе по факту загрузки с лимитами.
  Widget? _acImage(dom.Element el) {
    final src = el.attributes['src'] ?? '';
    if (!src.startsWith('https://img.ngfiles.com/')) return null;
    Size? natural;
    final wa = double.tryParse(el.attributes['width'] ?? '');
    final ha = double.tryParse(el.attributes['height'] ?? '');
    if (wa != null && ha != null && wa > 0 && ha > 0) {
      natural = Size(wa, ha);
    } else {
      final smart = el.attributes['data-smart-scale'];
      if (smart != null) {
        final parts = smart.split(',');
        final w = double.tryParse(parts[0].trim());
        final h =
            parts.length > 1 ? double.tryParse(parts[1].trim()) : null;
        if (w != null && h != null && w > 0 && h > 0) natural = Size(w, h);
      }
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: _gap),
      child: LayoutBuilder(builder: (context, cons) {
        final avail = cons.maxWidth.isFinite ? cons.maxWidth : _acWidth;
        return _AcImage(src: src, natural: natural, maxWidth: avail);
      }),
    );
  }

  /// Инлайн-содержимое блока в TextSpan: текст, `b`/`strong`,
  /// `i`/`em`, `u`, ссылки золотом и кликабельные. `br` внутри строки —
  /// перенос, а вот абзацы из одних `br` отсекаются уровнем блоков.
  /// [style] — накопленное оформление вложенных тегов.
  InlineSpan? _acInline(List<dom.Node> nodes, {TextStyle? style}) {
    TextStyle st(TextStyle Function(TextStyle) f) => f(style ?? ngBody);
    final spans = <InlineSpan>[];
    for (final n in nodes) {
      if (n is dom.Text) {
        final t = _acCollapse(n.text);
        if (t.isNotEmpty) spans.add(TextSpan(text: t, style: style));
      } else if (n is dom.Element) {
        switch (n.localName) {
          case 'br':
            // br в середине текста — перенос; но пустые br-абзацы
            // уже отфильтрованы, так что не добавляем голых \n.
            if (spans.isNotEmpty &&
                spans.any((s) =>
                    s is TextSpan && (s.text ?? '').trim().isNotEmpty)) {
              spans.add(const TextSpan(text: '\n'));
            }
          case 'b' || 'strong':
            final inner = _acInline(n.nodes,
                style: st((s) => s.copyWith(fontWeight: FontWeight.bold)));
            if (inner != null) spans.add(inner);
          case 'i' || 'em':
            final inner = _acInline(n.nodes,
                style: st((s) => s.copyWith(fontStyle: FontStyle.italic)));
            if (inner != null) spans.add(inner);
          case 'u':
            final inner = _acInline(n.nodes,
                style:
                    st((s) => s.copyWith(decoration: TextDecoration.underline)));
            if (inner != null) spans.add(inner);
          case 'a':
            final href = n.attributes['href'] ?? '';
            final inner = _acInline(n.nodes,
                style: st((s) => s.copyWith(
                    color: ngGold, decoration: TextDecoration.underline)));
            if (inner == null) break;
            if (href.isNotEmpty) {
              final idx = _links.length;
              _links.add(_acUrl(href));
              // WidgetSpan+GestureDetector: хит-зона на всём тексте ссылки,
              // не зависит от разбора жестов по листьям TextSpan.
              spans.add(WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openLink(idx),
                  child: Text.rich(inner,
                      style: ngBody.copyWith(height: 1.45)),
                ),
              ));
            } else {
              spans.add(inner);
            }
          case 'img':
            // Инлайн-картинки обрабатывает уровень блоков; здесь — зазор.
            spans.add(const TextSpan(text: ' '));
          default:
            final inner = _acInline(n.nodes, style: style);
            if (inner != null) spans.add(inner);
        }
      }
    }
    if (spans.isEmpty) return null;
    return TextSpan(children: spans);
  }

  /// Относительные ссылки NG → абсолютные, остальное — как есть.
  String _acUrl(String href) {
    if (href.startsWith('//')) return 'https:$href';
    if (href.startsWith('/')) return 'https://www.newgrounds.com$href';
    return href;
  }

  Future<void> _openLink(int idx) async {
    final url = _links[idx];
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  /// Схлопывание пробелов, как у HTML: переводы строк и табы → пробел.
  String _acCollapse(String t) => t.replaceAll(RegExp(r'\s+'), ' ');
}

/// Картинка комментов: скейл под реальную ширину пода (но не больше
/// [_acWidth]), только уменьшение; высокая — дополнительно по высоте.
class _AcImage extends StatelessWidget {
  final String src;
  final Size? natural;
  final double maxWidth;

  const _AcImage({required this.src, required this.maxWidth, this.natural});

  @override
  Widget build(BuildContext context) {
    Widget img = Image.network(
      src,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
    final nat = natural;
    if (nat != null && nat.width > 0 && nat.height > 0) {
      var w = nat.width;
      var h = nat.height;
      final maxW = maxWidth < _acWidth ? maxWidth : _acWidth;
      final s1 = (maxW / w).clamp(0.0, 1.0);
      w *= s1;
      h *= s1;
      if (h > _acMaxImgH) {
        final s2 = _acMaxImgH / h;
        w *= s2;
        h = _acMaxImgH;
      }
      img = SizedBox(width: w, height: h, child: img);
    } else {
      img = ConstrainedBox(
        constraints: const BoxConstraints(
            maxWidth: _acWidth, maxHeight: _acMaxImgH),
        child: img,
      );
    }
    return Align(alignment: Alignment.centerLeft, child: img);
  }
}

// ── Credits & Info: метаданные сабмишена + секция деталей ──────────────────

class _CreditsPod extends StatelessWidget {
  final Track track;
  const _CreditsPod({required this.track});

  @override
  Widget build(BuildContext context) {
    final t = track;
    final artist = t.artist;
    final score = double.tryParse(t.score ?? '') ?? 0;

    void openProfile() => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ArtistScreen(artist: artist)),
        );

    return NgPod.list(
      icon: 'user',
      title: 'Credits & Info',
      skin: _skin,
      action: NgPlateLink(label: 'Profile »', onTap: openProfile),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Первый `podcontent`: метаданные сабмишена
          Padding(
            padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _CreditRow(label: 'Date', value: t.uploaded ?? '—'),
                _CreditRow(
                  label: 'File Info',
                  value: t.fileInfo ??
                      (t.duration > 0
                          ? 'Song | ${NgTimeLabel.fmt(Duration(seconds: t.duration))}'
                          : '—'),
                ),
                _CreditRow(
                  label: 'Score',
                  value: t.votesPending != null
                      ? 'Waiting for ${t.votesPending} more '
                          'vote${t.votesPending == 1 ? '' : 's'}'
                      : score > 0
                          ? '${score.toStringAsFixed(2)} / 5.00'
                          : 'Not rated',
                ),
                if (t.votes != null)
                  _CreditRow(label: 'Votes', value: t.votes!),
                if (t.bpm != null && t.bpm!.isNotEmpty)
                  _CreditRow(label: 'BPM', value: t.bpm!),
                _TrackIdRow(trackId: t.id),
              ],
            ),
          ),
          // Второй `podcontent` того же пода: жанр, теги, статистика, шаринг
          const NgPodBreaker(),
          _DetailsSection(track: t),
        ],
      ),
    );
  }
}

// ── Коробка автора: аватар, ник, разделитель, кнопка подписки ────────────

class _AuthorPod extends StatefulWidget {
  final Track track;
  const _AuthorPod({required this.track});

  @override
  State<_AuthorPod> createState() => _AuthorPodState();
}

class _AuthorPodState extends State<_AuthorPod> {
  bool _following = false;
  bool? _followed;

  @override
  void initState() {
    super.initState();
    _loadFollowStatus();
  }

  @override
  void didUpdateWidget(_AuthorPod old) {
    super.didUpdateWidget(old);
    if (old.track.artist != widget.track.artist) {
      _followed = null;
      _loadFollowStatus();
    }
  }

  Future<void> _loadFollowStatus() async {
    final artist = widget.track.artist;
    if (artist.isEmpty) return;
    // Статус читается только по классу `active` на кнопке favefollow;
    // null остаётся, когда определить не удалось, и кнопка не врёт.
    final status = await NgRepository().getFollowStatus(artist);
    if (mounted) setState(() => _followed = status);
  }

  Future<void> _onFollowTap(NgViewModel vm) async {
    if (vm.currentUser == null) {
      await _requireLogin(
          context, vm, 'You need to be logged in to follow artists.');
      return;
    }

    final target = !(_followed ?? false);
    setState(() => _following = true);
    final confirmed =
        await vm.setFollow(widget.track.artist.toLowerCase(), target);
    if (!mounted) return;
    final ok = confirmed == target;
    setState(() {
      _following = false;
      if (ok) _followed = target;
    });
    _showNgSnack(
      context,
      ok
          ? (target
              ? 'Now following ${widget.track.artist}!'
              : 'Unfollowed ${widget.track.artist}')
          : (target ? 'Failed to follow' : 'Failed to unfollow'),
      ok: ok,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();
    final t = widget.track;
    final artist = t.artist;
    final followed = _followed == true;

    void openProfile() => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ArtistScreen(artist: artist)),
        );

    return NgPod(
      skin: _skin,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GestureDetector(
              onTap: openProfile,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: ngBlack,
                  border: Border.fromBorderSide(BorderSide(color: ngBrown)),
                ),
                child: t.authorIcon == null
                    ? Image.asset(NgTex.defaultAudioIcon, fit: BoxFit.cover)
                    : NgTrackIcon(url: t.authorIcon!, size: 32),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: openProfile,
                  child: Text(
                    artist.isEmpty ? '—' : artist,
                    style: ngLink.copyWith(fontSize: 14),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: ngHairline,
            ),
            Center(
              child: NgButton(
                label: _following
                    ? '…'
                    : followed
                        ? 'Following'
                        : 'Follow',
                icon: followed ? 'check' : 'user-add',
                width: 96,
                onPressed: _following ? null : () => _onFollowTap(vm),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ID сабмишена NG (числом, как в URL /audio/listen/…) с копированием в
/// буфер — для геометри дэш и прочих сервисов, которым нужен голый ID.
class _TrackIdRow extends StatelessWidget {
  final String trackId;
  const _TrackIdRow({required this.trackId});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text('ID',
                style: TextStyle(
                    fontSize: 11, color: ngDim, fontStyle: FontStyle.italic)),
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    trackId,
                    style: TextStyle(fontSize: 12, color: ngWhite),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Clipboard.setData(
                        ClipboardData(text: trackId));
                    _showNgSnack(context, 'Track ID copied');
                  },
                  child: Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(Icons.copy, size: 13, color: ngGold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Строка правой колонки `Credits & Info`: подпись курсивом, значение белым.
class _CreditRow extends StatelessWidget {
  final String label;
  final String value;
  const _CreditRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(label,
                style: TextStyle(
                    fontSize: 11, color: ngDim, fontStyle: FontStyle.italic)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, color: ngWhite),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Отзывы и оценка ─────────────────────────────────────────────────────

/// Под отзывов: своя оценка (votebar), список отзывов с пагинацией
/// и форма написания отзыва — как на странице сабмишена 2015.
class _ReviewsPod extends StatefulWidget {
  final Track track;
  const _ReviewsPod({required this.track});

  @override
  State<_ReviewsPod> createState() => _ReviewsPodState();
}

class _ReviewsPodState extends State<_ReviewsPod> {
  static final _repo = NgRepository();
  static const _sorts = [('date', 'Date'), ('score', 'Score')];

  ReviewsPage? _page;
  String _sort = 'date';
  // Направление: false — убывание (новые сверху / высокие сверху),
  // true — возрастание. Дефолт: свежие отзывы сверху.
  bool _asc = false;
  int _pageNum = 1;
  bool _loading = false;
  String? _error;

  /// Мой отзыв (синхронизирован с NG в `_load`); null — ещё не писал.
  NgReview? _myReview;
  /// Сохранённый голос в шкале NG 0..10 (null — не голосовал).
  int? _myVote;
  /// Форма открыта (написание или правка карандашом).
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    // NG сортирует только по убыванию. Для возрастания зеркалим страницы:
    // логическая страница 1 (старейшие) = последняя страница NG, развёрнутая.
    final known = _page?.pages ?? 1;
    final fetchPage = _asc ? (known - _pageNum + 1).clamp(1, known) : _pageNum;
    // Свой отзыв (он же синхронизирует голос из votebar-а страницы в
    // кэш) и список чужих — параллельно. Голос читаем из кэша ПОСЛЕ:
    // он только что обновился значением с сайта, второй запрос не нужен.
    final trackId = widget.track.id;
    final results = await Future.wait([
      _repo.getReviews(trackId, sort: _sort, page: fetchPage),
      _repo.getMyReview(trackId),
    ]);
    if (!mounted) return;
    final vote = await NgAuth.getMyVote(trackId);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _page = results[0] as ReviewsPage?;
      _error = _page == null ? 'Could not load reviews' : null;
      _myReview = results[1] as NgReview?;
      _myVote = vote;
    });
  }

  /// Отправка ответа автора; при успехе дожидаемся перезагрузки отзывов,
  /// чтобы после закрытия диалога ответ уже стоял в карточке.
  Future<String?> _respond(String reviewId, String text) async {
    final err = await _repo.postResponse(reviewId, text);
    if (err == null) await _load();
    return err;
  }

  void _go(int p) {
    _pageNum = p.clamp(1, _page?.pages ?? 1);
    _load();
  }

  /// Тап по пункту сортировки: неактивный — включить ключ (убывание,
  // дефолт NG); активный — развернуть направление на месте.
  void _toggleSort(String key) {
    if (_sort == key) {
      _pageNum = 1;
      _asc = !_asc;
      _load();
    } else {
      _sort = key;
      _asc = false;
      _pageNum = 1;
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();
    // Reply доступен только автору трека (проверка дублем на сервере NG:
    // форму /reviews/responses/create/{id} видно только владельцу).
    final canRespond = vm.currentUser != null &&
        vm.currentUser!.username.toLowerCase() ==
            widget.track.artist.toLowerCase();
    return NgPod(
      icon: 'speech',
      title: 'Reviews',
      skin: _skin,
      padding: const EdgeInsets.fromLTRB(11, 15, 11, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Блок «Your Review»: голос + свой отзыв + карандаш ────────
          if (vm.currentUser != null) ...[
            _VoteBar(
              trackId: widget.track.id,
              savedVote: _myVote,
              onVoted: (v) => setState(() => _myVote = v),
            ),
            const SizedBox(height: 10),
            if (_editing || (_myReview == null))
              _WriteReview(
                vm: vm,
                track: widget.track,
                existing: _editing ? _myReview : null,
                stars: _myVote ?? 0,
                onCancel: _myReview != null
                    ? () => setState(() => _editing = false)
                    : null,
                onSaved: (r) => setState(() {
                  _myReview = r;
                  _editing = false;
                }),
              )
            else
              _MyReviewBlock(
                review: _myReview!,
                onEdit: () => setState(() => _editing = true),
              ),
            const SizedBox(height: 12),
          ],

          // ── Чужие отзывы ────────────────────────────────────────────
          if (_loading)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(
                  child: Text('Loading…', style: ngLabel)),
            )
          else if (_error != null)
            Column(children: [
              Text(_error!, style: ngLabel.copyWith(color: ngWhite)),
              const SizedBox(height: 6),
              NgButton(label: 'Retry', onPressed: _load),
            ])
          else if (_page == null || _page!.items.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('No reviews yet. Be the first!', style: ngLabel),
            )
          else ...[
            // `div.pagenav` 2024: сортировка слева, страницы справа.
            Builder(builder: (context) {
              // NG всегда отдаёт убывание (новые/высокие сверху) —
              // разворачиваем список при выборе возрастания.
              final items =
                  _asc ? _page!.items.reversed.toList() : _page!.items;
              return Column(children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // div.sort: ссылки без плашек; активная — жирная со
                    // стрелкой направления (▼ убывание / ▲ возрастание).
                    // БЕЗ Spacer/Expanded: плахи сорта Lëжат в Row внутри
                    // Column(mainAxisSize.max) у вертикального скролла, и
                    // flex-ребецок в неограниченной высоте давал весь блок
                    // MISSING (сорта уползали в левый верх рамки Rate).
                    Text('Sort By: ', style: ngLabel),
                    for (var i = 0; i < _sorts.length; i++) ...[
                      if (i > 0) Text(' | ', style: ngLabel),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _toggleSort(_sorts[i].$1),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _sorts[i].$2,
                              style: _sort == _sorts[i].$1
                                  ? ngLabel.copyWith(
                                      color: ngGold,
                                      fontWeight: FontWeight.bold)
                                  : ngLabel,
                            ),
                            if (_sort == _sorts[i].$1)
                              Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: Text(
                                  _asc ? '▲' : '▼',
                                  style: ngLabel.copyWith(
                                      color: ngGold, fontSize: 9),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                    // Пагинатор показываем только когда есть куда листать
                    // (отзывов больше, чем влезает в одну страницу — NG
                    // кладёт до 5 карточек на страницу, и pages>1). Иначе
                    // пара кнопок «1» мелькает впустую под 2 отзывами.
                    if (_page!.pages > 1) ...[
                      const SizedBox(width: 12),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: _ReviewPager(
                              page: _page!.page,
                              pages: _page!.pages,
                              onGo: _go),
                        ),
                      ),
                    ],
                  ],
                ),
                const NgHr(margin: EdgeInsets.symmetric(vertical: 6)),
                // Карточки разделены тонкой чертой, без рамок.
                for (var i = 0; i < items.length; i++) ...[
                  _ReviewCard(
                    review: items[i],
                    canRespond: canRespond,
                    onRespond: _respond,
                  ),
                  if (i < items.length - 1)
                    const NgHr(margin: EdgeInsets.symmetric(vertical: 4)),
                ],
                const SizedBox(height: 6),
              ]);
            }),
          ],
        ],
      ),
    );
  }
}

/// Votebar NG 2024 (мобильный эталон `Back To Life.mht`):
/// слева blam-звезда (Vote 0), затем бар из 5 звёзд (спрайт star-select-2,
/// тайл = весь файл, сжатый до 46.15×204.92; кадры по 41: hover/idle/checked/
/// idle/blam), каждая звезда — ДВЕ тап-зоны по ползвезды (голос 1..10),
/// справа — реакция Стива (SteveReact4, 11 кадров по 40, кадр = голос).
///
/// NG после голоса убирает votebar со страницы — сохранённый голос приходит
/// извне ([savedVote], звёзды 0..5) и подсвечивается золотым.
class _VoteBar extends StatefulWidget {
  final String trackId;
  final int? savedVote; // 0..5, null — ещё не голосовал
  final ValueChanged<int> onVoted;

  const _VoteBar({
    required this.trackId,
    required this.onVoted,
    this.savedVote,
  });

  @override
  State<_VoteBar> createState() => _VoteBarState();
}

class _VoteBarState extends State<_VoteBar> {
  static final _repo = NgRepository();

  /// Голос в шкале NG 0..10; null — ещё не голосовал (серые звёзды).
  int? _voted;
  bool _busy = false;
  String? _note;

  /// Превью-оценка во время зажатия/драга (0..10) — видна в шапке.
  int? _preview;

  /// «4.5» из голоса NG 0..10 — как сайт пишет в «You voted N!».
  static String _stars(int v) =>
      (v / 2).toStringAsFixed(v.isOdd ? 1 : 0);

  @override
  void initState() {
    super.initState();
    // savedVote — уже в шкале NG 0..10 (полузвёзды).
    _voted = widget.savedVote;
  }

  @override
  void didUpdateWidget(_VoteBar old) {
    super.didUpdateWidget(old);
    if (widget.savedVote != old.savedVote) {
      _voted = widget.savedVote;
    }
  }

  Future<void> _vote(int value, NgViewModel vm) async {
    if (_busy || value < 0 || value > 10) return;
    if (vm.currentUser == null) {
      await _requireLogin(context, vm, 'Log in to rate this audio.');
      return;
    }
    setState(() {
      _busy = true;
      _note = null;
      // Сразу показываем, чем голосуем — до ответа NG.
      _preview = value;
    });
    // voteTrack ждёт голос в шкале NG 0..10 (полузвёзды).
    final res = await _repo.voteTrack(widget.trackId, value);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _preview = null;
      if (res == null) {
        _note = 'Vote failed — try again';
      } else {
        _voted = value;
        _note = res.waiting
            ? (res.pendingVotes != null
                ? 'Waiting for ${res.pendingVotes} more '
                    'vote${res.pendingVotes == 1 ? '' : 's'}…'
                : 'Waiting for more votes…')
            : 'You voted ${_stars(value)}!';
        // Наверх — голос в шкале NG 0..10, без округлений, иначе
        // didUpdateWidget перерисует полузвёзды как целые звёзды.
        widget.onVoted(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<NgViewModel>();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F0D0D),
        border: Border.all(color: const Color(0xFF262523)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      child: Column(
        children: [
          Text(
            _busy
                ? 'Voting ${_stars(_preview ?? 0)}…'
                : _preview != null
                    ? _stars(_preview!)
                    : _note ??
                        (_voted != null && _voted! > 0
                            ? 'You Rated This ${_stars(_voted!)}/5'
                            : 'RATE THIS SUBMISSION!'),
            style: TextStyle(
              fontFamily: ngHeaderFont,
              fontSize: 16,
              color: (_note != null || (_voted != null && _voted! > 0)) && !_busy
                  ? ngGold
                  : ngWhite,
              shadows: [Shadow(color: ngBlack, offset: Offset(0, 1))],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            "Vote fairly! Haters and ass-kissers don't help anybody.",
            style: TextStyle(fontSize: 9, color: ngDim),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          if (themeCtl.textured)
            // 2015: шесть лиц 0..5 (голос = лицо × 2).
            _VoteFaceRow(
              selected: _voted ?? 0,
              dimUnselected: (_voted ?? 0) > 0,
              enabled: !_busy,
              onSelect: (f) => _vote(f * 2, vm),
            )
          else
            // Во время отправки бар показывает именно ту оценку, что уходит
            // в NG (_preview зафиксирован в момент отпускания пальца), а не
            // старую — иначе при смене 5 → 4 звёзды «не доезжают».
            NgVoteStars(
              voted: _busy && _preview != null ? _preview : _voted,
              enabled: !_busy,
              onVote: (v) => _vote(v, vm),
              onPreview: (v) => setState(() => _preview = v),
            ),
        ],
      ),
    );
  }
}


/// Ряд из шести лиц votebar 2015 (0..5): спрайт `vp/vote-darn.png`.
/// [selected] — выбранное лицо (0 — ничего); [dimUnselected] притеняет
/// невыбранные после голоса. В 2024-теме не используется.
class _VoteFaceRow extends StatelessWidget {
  final int selected;
  final bool enabled;
  final bool dimUnselected;
  final ValueChanged<int> onSelect;

  const _VoteFaceRow({
    required this.selected,
    required this.onSelect,
    this.enabled = true,
    this.dimUnselected = false,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var f = 0; f <= 5; f++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: enabled ? () => onSelect(f) : null,
              child: Opacity(
                opacity: dimUnselected && selected != f ? 0.45 : 1,
                child:
                    _VoteFace(face: f, active: selected == f && selected > 0),
              ),
            ),
        ],
      ),
    );
  }
}

/// Одно лицо votebar: вырезка 50×55 из спрайта 300×230.
/// Столбец f (0..5) → alignX; idle-ряд на y=55, нажатый — внизу (y=175).
class _VoteFace extends StatelessWidget {
  final int face;
  final bool active;
  const _VoteFace({required this.face, required this.active});

  @override
  Widget build(BuildContext context) {
    final align = Alignment(-1 + face * 0.4, active ? 1.0 : -0.371);
    return SizedBox(
      width: 50,
      height: 55,
      child: ClipRect(
        child: OverflowBox(
          minWidth: 0,
          minHeight: 0,
          maxWidth: 300,
          maxHeight: 230,
          alignment: align,
          child: Image.asset(
            NgTex.voteFaces,
            width: 300,
            height: 230,
            fit: BoxFit.fill,
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}

/// Карточка ЧУЖОГО отзыва как на NG 2015: шапка (круглый аватар, ник
/// оранжевым, флажок-жалоба, звёзды справа), текст, низ с «React» и
/// счётчиком реакций. Рамки нет — карточки разделены тонкой чертой.
class _ReviewCard extends StatelessWidget {
  final NgReview review;

  /// Текущий пользователь — автор трека: только ему NG даёт отвечать
  /// на отзывы (кнопка Reply в его же карточках).
  final bool canRespond;

  /// Коллбек отправки ответа (текст, id отзыва).
  final Future<String?> Function(String reviewId, String text)? onRespond;

  const _ReviewCard({
    required this.review,
    this.canRespond = false,
    this.onRespond,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Шапка: аватар + ник + флажок … звёзды ────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (review.avatarUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ClipOval(
                    child: Image.network(review.avatarUrl,
                        width: 26, height: 26, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(
                            width: 26, height: 26)),
                  ),
                ),
              // Левая часть шапки одним Expanded: ник + дата рядом,
              // переполнение сжатиет ник с многоточием. Флажок и звёзды —
              // несжимаемые, всегда прижаты к правому краю без «шатания».
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        review.author,
                        style: ngLink.copyWith(
                            fontWeight: FontWeight.bold, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Дата сразу после ника, небольшой отступ.
                    if (review.date.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(review.date,
                          style: ngLabel.copyWith(fontSize: 9)),
                    ],
                  ],
                ),
              ),
              if (review.hasScore) NgStars(score: review.score),
            ],
          ),
          if (review.body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                review.body,
                style: ngBody.copyWith(fontSize: 12, color: ngWhite),
              ),
            ),
          // ── Ответ автора трека (div.authresponse) ─────────────────
          if (review.response != null)
            _AuthorResponse(response: review.response!),
          // ── Reply: только владелец трека ─────────────────────
          if (canRespond && onRespond != null)
            _ReplyButton(
              onTap: () => _showResponseForm(context, review.id),
            ),
        ],
      ),
    );
  }

  /// Форма ответа: «Your Response:» + textarea + Submit, как на NG
  /// (pod с формой `/reviews/responses/create/{id}`).
  void _showResponseForm(BuildContext context, String reviewId) {
    final ctrl = TextEditingController();
    var busy = false;
    showDialog(
      context: context,
      barrierColor: ngBlack.withValues(alpha: 0.72),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          Future<void> submit() async {
            final text = ctrl.text.trim();
            if (text.isEmpty || busy) return;
            setDlg(() => busy = true);
            final err = await onRespond!(reviewId, text);
            if (!ctx.mounted) return;
            Navigator.pop(ctx);
            _showNgSnack(ctx, err ?? 'Response posted!', ok: err == null);
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: NgPod(
              icon: 'speech',
              title: 'New Response',
              skin: _skin,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Your Response:', style: ngLabel),
                  const SizedBox(height: 5),
                  // Поле 2024 — тёмно-серое, как на сайте.
                  Container(
                    height: 84,
                    decoration: BoxDecoration(
                      color: const Color(0xFF282B30),
                      border: Border.all(color: ngHairline),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: TextField(
                      controller: ctrl,
                      maxLines: null,
                      autofocus: true,
                      cursorColor: ngGold,
                      cursorWidth: 1,
                      onSubmitted: (_) => submit(),
                      style: TextStyle(color: ngText, fontSize: 12),
                      decoration: const InputDecoration(
                        isDense: true,
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                            horizontal: 5, vertical: 4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      NgButton(
                          label: 'Cancel', onPressed: () => Navigator.pop(ctx)),
                      const SizedBox(width: 8),
                      NgButton(
                        label: busy ? 'Sending…' : 'Submit',
                        onPressed: busy ? null : submit,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Жалоба: NG показывает диалог подтверждения на /flag/add/… —
  /// открываем во внешнем браузере (там нужен залогиненный веб).
  /// UI-кнопка временно скрыта (репорт не реализован).
  // ignore: unused_element
  void _openFlag(BuildContext context) {
    final url = review.flagUrl.startsWith('http')
        ? review.flagUrl
        : 'https://www.newgrounds.com${review.flagUrl}';
    final uri = Uri.tryParse(url);
    if (uri != null) {
      launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

/// Ответ автора трека (div.authresponse): аватар + «ник responds:»
/// и текст — как на NG, под текстом отзыва.
class _AuthorResponse extends StatelessWidget {
  final NgReviewResponse response;
  const _AuthorResponse({required this.response});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: Color(0xFF14110E),
        border: Border.fromBorderSide(BorderSide(color: ngHairline)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (response.avatarUrl.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(right: 5),
                  child: ClipOval(
                    child: Image.network(response.avatarUrl,
                        width: 18, height: 18, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const SizedBox(width: 18, height: 18)),
                  ),
                ),
              Expanded(
                child: Text.rich(
                  TextSpan(children: [
                    TextSpan(
                      text: response.author.isEmpty
                          ? 'Author'
                          : response.author,
                      style: ngLink.copyWith(
                          fontWeight: FontWeight.bold, fontSize: 11),
                    ),
                    TextSpan(
                      text: ' responds:',
                      style: ngLabel.copyWith(fontSize: 11),
                    ),
                  ]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (response.body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                response.body,
                style: ngBody.copyWith(fontSize: 11, color: ngText),
              ),
            ),
        ],
      ),
    );
  }
}

/// Кнопка «Reply» (ngicon-25-comment): иконка-облачко + слово Reply,
/// золотым, справа под текстом отзыва.
class _ReplyButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ReplyButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.chat_bubble_outline,
                  size: 14, color: ngGold),
              const SizedBox(width: 4),
              Text('Reply',
                  style: ngLink.copyWith(
                      fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }
}

/// `div.pagenav` 2024: слева «Sort By: Date/Score» (без плашек, ссылки),
/// справа — числовые кнопки-плашки с градиентом `#34393D→#4E575E`
/// (те же, что у кнопок шапки); активная страница — текст без плашки.
class _ReviewPager extends StatelessWidget {
  final int page;
  final int pages;
  final ValueChanged<int> onGo;

  const _ReviewPager({required this.page, required this.pages, required this.onGo});

  @override
  Widget build(BuildContext context) {
    // Номера вокруг текущей: [1 … n-1 n n+1 … last]
    final nums = <int>{
      1,
      pages,
      page - 1,
      page,
      page + 1,
    }.where((n) => n >= 1 && n <= pages).toList()..sort();

    Widget numBtn(int n) {
      final active = n == page;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: active ? null : () => onGo(n),
        child: Container(
          // .pagenav a: та же плашка, что у кнопок шапки 2024; у текущей
          // страницы фон тот же, но цифра белая.
          height: 22,
          constraints: const BoxConstraints(minWidth: 22),
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
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
            border: Border.all(color: const Color(0xFF34393D), width: 2),
            borderRadius: const BorderRadius.all(Radius.circular(4)),
          ),
          child: Text(
            '$n',
            style: TextStyle(
              fontFamily: 'Arial',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: active ? ngWhite : ngGold,
            ),
          ),
        ),
      );
    }

    Widget gap(int a, int b) =>
        b - a > 1 ? Padding(
              padding: EdgeInsets.symmetric(horizontal: 3),
              child: Text('…', style: TextStyle(color: ngDim, fontSize: 13)),
            ) : const SizedBox(width: 3);

    var seq = <Widget>[numBtn(nums.first)];
    for (var i = 1; i < nums.length; i++) {
      seq..add(gap(nums[i - 1], nums[i]))..add(numBtn(nums[i]));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ...seq,
        ],
      ),
    );
  }
}

/// Форма написания/правки отзыва: textarea 2015 + Submit. Оценка ставится
/// отдельно — лицами в рамке «RATE THIS SUBMISSION!» выше.
/// [existing] — режим правки карандашом: предзаполняет текст,
/// шлёт POST на /reviews/edit/{id}; [onCancel] показывает кнопку отмены.
class _WriteReview extends StatefulWidget {
  final NgViewModel vm;
  final Track track;
  final NgReview? existing;
  final VoidCallback? onCancel;
  final ValueChanged<NgReview> onSaved;

  /// Оценка, связанная с отзывом: берётся из рамки «RATE THIS SUBMISSION!»
  /// (там теперь единственное место выбора оценки). 0 — ещё не выбрана.
  final int stars;

  const _WriteReview({
    required this.vm,
    required this.track,
    required this.onSaved,
    this.existing,
    this.onCancel,
    this.stars = 0,
  });

  @override
  State<_WriteReview> createState() => _WriteReviewState();
}

class _WriteReviewState extends State<_WriteReview> {
  static final _repo = NgRepository();
  late final TextEditingController _ctrl;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.existing?.body ?? '');
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (_busy) return;
    if (widget.vm.currentUser == null) {
      await _requireLogin(context, widget.vm, 'Log in to write a review.');
      return;
    }
    if (text.isEmpty) {
      _showNgSnack(context, 'Review text is empty', ok: false);
      return;
    }
    if (widget.stars < 1) {
      _showNgSnack(context, 'Rate this submission first', ok: false);
      return;
    }
    setState(() => _busy = true);
    final err = _isEdit
        ? await _repo.editReview(
            widget.existing!.id, widget.track.id, text, widget.stars)
        : await _repo.postReview(widget.track.id, text, widget.stars);
    if (!mounted) return;
    setState(() => _busy = false);
    if (err == null) {
      _showNgSnack(context, _isEdit ? 'Review updated!' : 'Review posted!');
      // ID у нового отзыва появится при следующей синхронизации с NG —
      // сохраняем то, что знаем; под перерисуется.
      widget.onSaved(NgReview(
        id: _isEdit ? widget.existing!.id : '',
        author: 'You',
        authorSlug: '',
        avatarUrl: '',
        date: _isEdit ? widget.existing!.date : 'Just now',
        score: widget.stars.toDouble(),
        body: text,
      ));
    } else if (err == 'not logged in') {
      await _requireLogin(context, widget.vm, 'Log in to write a review.');
    } else {
      _showNgSnack(context, err, ok: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          _isEdit ? 'Edit your review:' : 'Write a review:',
          style: ngLabel.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (themeCtl.textured) ...[
          // Многострочное поле 2015 — золотистая текстура input-gold.
          Container(
            height: 72,
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
            child: TextField(
              controller: _ctrl,
              maxLines: null,
              cursorColor: ngInk,
              cursorWidth: 1,
              style: const TextStyle(color: Color(0xFF1B1006), fontSize: 12),
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Share your feedback on this audio here!',
                hintStyle: TextStyle(color: Color(0xFF7A5A20), fontSize: 12),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              ),
            ),
          ),
        ] else ...[
          // Многострочное поле 2024 — тёмно-серое (rgb(40,43,48)), как
          // поля поиска/ввода на сайте.
          Container(
            height: 72,
            decoration: BoxDecoration(
              color: const Color(0xFF282B30),
              border: Border.all(color: ngHairline),
              borderRadius: BorderRadius.circular(4),
            ),
            child: TextField(
              controller: _ctrl,
              maxLines: null,
              cursorColor: ngGold,
              cursorWidth: 1,
              style: TextStyle(color: ngText, fontSize: 12),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Share your feedback on this audio here!',
                hintStyle: TextStyle(color: ngDim, fontSize: 12),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 5, vertical: 4),
              ),
            ),
          ),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (_isEdit && widget.onCancel != null) ...[
              NgButton(label: 'Cancel', onPressed: widget.onCancel),
              const SizedBox(width: 8),
            ],
            NgButton(
              label: _busy ? 'Saving…' : 'Submit',
              onPressed: _busy ? null : _submit,
            ),
          ],
        ),
      ],
    );
  }
}

/// Блок «Your Review»: моя карточка с пометкой (You), оценкой-рожами
/// и карандашом для правки. Стоит в поде Reviews выше чужих отзывов.
class _MyReviewBlock extends StatelessWidget {
  final NgReview review;
  final VoidCallback onEdit;

  const _MyReviewBlock({required this.review, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Your Review', style: ngLabel.copyWith(color: ngGold)),
            const Spacer(),
            // Карандаш из спрайта a15 — правка текста и оценки.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onEdit,
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Image.asset(NgTex.a15('pencil'),
                    width: 18, height: 18),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF14110E),
            border: Border.all(color: ngGold, width: 1),
          ),
          padding: const EdgeInsets.all(7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'You',
                      style: ngLink.copyWith(
                          fontWeight: FontWeight.bold, fontSize: 12,
                          color: ngGold),
                    ),
                  ),
                  // 2015 показывает оценку отзыва лицами, 2024 — без неё
                  // (оценка живёт в рамке голосования над формой).
                  if (themeCtl.textured && review.hasScore)
                    _VoteFaceRow(
                      selected: review.score.round().clamp(0, 5),
                      dimUnselected: true,
                      enabled: false,
                      onSelect: (_) {},
                    ),
                ],
              ),
              if (review.date.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(review.date,
                      style: ngLabel.copyWith(fontSize: 10)),
                ),
              if (review.body.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    review.body,
                    style: ngBody.copyWith(fontSize: 12, color: ngWhite),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
