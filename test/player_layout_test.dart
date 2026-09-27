import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngmusic/ui/theme/ng_theme.dart';
import 'package:ngmusic/ui/screens/player_screen.dart';
import 'package:ngmusic/ui/widgets/ng_player.dart';
import 'package:ngmusic/ui/widgets/ng_retro.dart';

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(1080, 2400);
    view.devicePixelRatio = 2.625;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });
  });

  testWidgets('Author Comments: пустой p>br — ровно одна пустая строка', (tester) async {
    const html =
        '<p>I made something new</p><p><br /></p><p><strong><u>Follow Junior Paes here</u></strong></p>'
        '<p><a href="https://open.spotify.com/artist/x">Spotify</a></p><p><br /></p><p><br /></p><p>Bye</p>';
    await tester.pumpWidget(MaterialApp(
      theme: ngTheme,
      home: Scaffold(
        backgroundColor: ngBlack,
        body: SingleChildScrollView(
          child: AuthorCommentsTestable(html: html),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final blanks = tester
        .widgetList<SizedBox>(find.byType(SizedBox))
        .where((sb) => sb.height == 18.0)
        .length;
    expect(blanks, 2, reason: 'две пустые секции в html, каждая — один бланк');
    final bareNl = tester
        .widgetList<Text>(find.byType(Text))
        .where((t) => (t.data ?? '').trim().isEmpty && (t.data ?? '').contains('\n'));
    expect(bareNl, isEmpty);
  });

  testWidgets('плеер целиком раскладывается и рисуется', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: ngTheme,
      home: Scaffold(
        backgroundColor: ngBlack,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(height: 44, color: ngBlack),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                  child: Column(
                    children: [
                      const NgPlayerStage(
                        playing: true,
                        position: Duration(seconds: 42),
                        duration: Duration(minutes: 3, seconds: 20),
                      ),
                      const SizedBox(height: 10),
                      const NgPod.list(
                        icon: 'audio',
                        title: 'Track Info',
                        skin: NgSkin.green,
                        child: NgInfoTable(
                          skin: NgSkin.green,
                          items: [
                            NgInfoItem('Genre', 'Song - Ambient'),
                            NgInfoItem('Score', '4.20 / 5.00',
                                below: NgStars(score: 4.2)),
                            NgInfoItem('Listens', '1,024'),
                          ],
                        ),
                      ),
                      NgPod(
                        icon: 'user',
                        title: 'sqooqs',
                        skin: NgSkin.green,
                        action: NgPlateLink(label: 'Profile »', onTap: () {}),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text('Follow to keep up with new '
                                  'submissions.', style: ngBody),
                            ),
                            const SizedBox(width: 10),
                            NgButton(
                                label: 'Follow',
                                icon: 'user-add',
                                onPressed: () {}),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));

    expect(tester.takeException(), isNull);
    expect(find.text('Track Info'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);

    final stage = tester.getSize(find.byType(NgPlayerStage));
    expect(stage.width, greaterThan(300));
    expect(stage.height, lessThan(120));
  });

  testWidgets('ландшафт: сцена с фиксированной обложкой не режет бары', (tester) async {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(2400, 1080);
    view.devicePixelRatio = 2.625;
    addTearDown(() {
      view.resetPhysicalSize();
      view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(MaterialApp(
      theme: ngTheme,
      home: Scaffold(
        body: SafeArea(
          child: SingleChildScrollView(
            child: NgPlayerStage(
              artUrls: const ['https://example.com/art.png'],
              artHeight: 203,
              position: const Duration(seconds: 42),
              duration: const Duration(minutes: 3, seconds: 20),
            ),
          ),
        ),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 120));

    expect(tester.takeException(), isNull);
    final stageRect = tester.getRect(find.byType(NgPlayerStage));
    expect(stageRect.height, 203 + 92 + 2);

    final timeRect = tester.getRect(find.byType(NgTimeLabel));
    expect(timeRect.bottom, lessThanOrEqualTo(stageRect.bottom));
  });

  testWidgets('NgVoteStars: драг даёт полузвёзды, тап по blam — ноль', (tester) async {
    var voted = -1;
    await tester.pumpWidget(MaterialApp(
      theme: ngTheme,
      home: Scaffold(
        backgroundColor: ngBlack,
        body: Center(
          child: NgVoteStars(
            voted: 7,
            onVote: (v) => voted = v,
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    final bar = find.byType(NgVoteStars);
    expect(tester.getSize(bar).height, 41);

    final rect = tester.getRect(bar);
    final barX = rect.left + 46.15 + 2;
    final g = await tester.startGesture(Offset(barX + 46.0, rect.center.dy));
    await tester.pump();
    await g.moveBy(const Offset(115.4, 0));
    await tester.pump();
    await g.up();
    await tester.pump();
    expect(voted, 7);

    await tester.tapAt(Offset(barX + 23.0, rect.center.dy));
    await tester.pump();
    expect(voted, 1);

    await tester.tapAt(Offset(rect.left + 20, rect.center.dy));
    await tester.pump();
    expect(voted, 0);
  });

  testWidgets('иконки трофеев режутся из спрайта', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Column(
          children: [
            NgTrophyIcon(kind: 'frontpage', size: 28),
            NgTrophyIcon(kind: 'daily1'),
            NgTrophyIcon(kind: 'monthly2'),
            NgTrophyIcon(kind: 'whatever'),
          ],
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(NgTrophyIcon.knows('frontpage'), isTrue);
    expect(NgTrophyIcon.knows('whatever'), isFalse);
    expect(tester.getSize(find.byType(NgTrophyIcon).first), const Size(28, 28));
  });
}
