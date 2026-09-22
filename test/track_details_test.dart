// Парсинг страницы трека `/audio/listen/{id}` на сохранённой копии — без сети.
// Разметку проверяли по живой странице (см. test/fixtures) и по ng2015/audioData.js.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ngmusic/data/model/track.dart';
import 'package:ngmusic/data/repository/ng_repository.dart';

Track _blank() => Track(
      id: '1580000',
      title: 'Xenoglossy',
      artist: '8-BiTek',
      genre: '',
      iconUrl: '',
      duration: 0,
      audioType: 3,
    );

/// Фикстура 1572356 — id финален, поэтому отдельный конструктор.
Track _legacy() => Track(
      id: '1572356',
      title: 'Xenoglossy',
      artist: '8-BiTek',
      genre: '',
      iconUrl: '',
      duration: 0,
      audioType: 3,
    );

void main() {
  test('sidestats со страницы трека разбираются в поля Track', () {
    final html =
        File('test/fixtures/listen_1572356.html').readAsStringSync();
    final track = _legacy();

    NgRepository().parseListenDetails(track, html);

    expect(track.listens, '3,754');
    expect(track.downloads, '53');
    expect(track.votes, '26');
    expect(track.faves, '11');
    expect(track.score, '4.78');
    expect(track.uploaded, 'May 27, 2026');
    expect(track.genre, 'Hip Hop - Olskool');
    expect(track.fileInfo, contains('MB'));
    expect(track.fileInfo, contains('Song'));
    expect(track.description, contains('random garba'));
    expect(track.license, contains('Please contact me'));
  });

  test('Waiting for N more votes: балл спрятан, остаток сохранён', () {
    final html =
        File('test/fixtures/listen_waiting.html').readAsStringSync();
    final track = _blank();

    NgRepository().parseListenDetails(track, html);

    // NG прячет оценку, пока голосов меньше пяти: вместо звёзд —
    // «Waiting for 3 more votes». Парсер должен сохранить остаток
    // и не оставить фейковый score с прошлого парсинга.
    expect(track.votesPending, 3);
    expect(track.score, isNull);
    expect(track.listens, '96');
  });

  test('ul.trophies даёт награды, включая Frontpaged', () {
    final track = _blank();
    NgRepository().parseListenDetails(track, '''
      <ul class="trophies">
        <li class="frontpage"><div class="flex-1 padded-vert">
          <strong>Frontpaged</strong> <a href="/fpa/audio/6/2026">June 17, 2026</a>
        </div></li>
        <li class="monthly4"><div><strong>Monthly 4th Place</strong> June 2026</div></li>
      </ul>
    ''');

    expect(track.awards.length, 2);
    expect(track.awards.first.kind, 'frontpage');
    expect(track.awards.first.label, 'Frontpaged');
    expect(track.awards.first.date, 'June 17, 2026');
    expect(track.awards[1].label, 'Monthly 4th Place');
    expect(track.awards[1].date, contains('June 2026'));
  });

  test('теги собираются из ссылок /audio/browse/tag/', () {
    final track = _blank();
    NgRepository().parseListenDetails(track, '''
      <a href="https://www.newgrounds.com/audio/browse/tag/chiptune">chiptune</a>
      <a href="https://www.newgrounds.com/audio/browse/tag/8bit">8bit</a>
      <a href="https://www.newgrounds.com/audio/browse/tag/chiptune">chiptune</a>
    ''');

    expect(track.tags, ['8bit', 'chiptune']);
  });

  test('теги 2026: search/conduct/audio?match=tags разбираются', () {
    final track = _blank();
    NgRepository().parseListenDetails(track, '''
      <dl class="sidestats flex-1">
        <dt class="tags">Tags</dt>
        <dd class="tags">
          <ul>
            <li><a href="https://www.newgrounds.com/search/conduct/audio?match=tags&amp;tags=classical">classical</a></li>
            <li><a href="https://www.newgrounds.com/search/conduct/audio?match=tags&amp;tags=orchestral">orchestral</a></li>
          </ul>
        </dd>
      </dl>
    ''');

    expect(track.tags, ['classical', 'orchestral']);
  });

  test('теги со сохранённой страницы Holy Knight Yusto', () {
    final html =
        File('test/fixtures/listen_yusto.html').readAsStringSync();
    final track = _blank();

    NgRepository().parseListenDetails(track, html);

    expect(track.tags, contains('classical'));
    expect(track.tags, contains('orchestral'));
  });

  test('Author Comments: HTML с картинками сохраняется вместе с текстом', () {
    final html =
        File('test/fixtures/listen_1572356.html').readAsStringSync();
    final track = _legacy();

    NgRepository().parseListenDetails(track, html);

    // Сырой HTML дошёл до UI: абзацы и обе картинки на месте.
    expect(track.descriptionHtml, isNotNull);
    expect(track.descriptionHtml, contains('<p>'));
    expect(track.descriptionHtml,
        contains('https://img.ngfiles.com/image-uploads/'));
    expect(
        RegExp('iu_1601784_20599008.webp').hasMatch(track.descriptionHtml!),
        isTrue);
    // Плоский текст по-прежнему рядом — фоллбэк для рендера.
    expect(track.description, contains('random garba'));
    // Картинки не должны попадать в плоский текст-фоллбэк.
    expect(track.description, isNot(contains('img.ngfiles.com')));
  });

  test('поиск по ID: страница listen разбирается в трек', () {
    final html =
        File('test/fixtures/listen_1572356.html').readAsStringSync();
    final repo = NgRepository();
    final t = repo.trackFromListenPage('1572356', html);

    expect(t, isNotNull);
    expect(t!.id, '1572356');
    expect(t.title, 'DPI-filtration');
    expect(t.artist, 'H31072');
    expect(t.iconUrl, contains('aicon.ngfiles.com'));
    expect(t.mp3Url, contains('audio.ngfiles.com'));

    // Обогащение из того же html (как это делает getTrackById):
    // статистика, жанр, теги и комменты приезжают сразу.
    repo.enrichFromHtml(t, html);
    expect(t.listens, '3,754');
    expect(t.score, '4.78');
    expect(t.genre, 'Hip Hop - Olskool');
    expect(t.uploaded, 'May 27, 2026');
    expect(t.descriptionHtml, isNotNull);
  });

  test('мой голос парсится из checked-радио votebar-а', () {
    final html = File('test/fixtures/listen_voted.html').readAsStringSync();
    final repo = NgRepository();

    // На этой странице голос стоит: сервер отрендерил checked на 10 (5 звёзд).
    expect(repo.parseMyVote(html), 10);

    // Страница без голоса: checked нет → null, кэш не трогаем.
    final noVote =
        File('test/fixtures/listen_1572356.html').readAsStringSync();
    expect(repo.parseMyVote(noVote), isNull);
  });

  test('обложка отдаётся кандидатами от _raw.png к превью', () {
    final track = _legacy()
      ..iconUrl = 'https://aicon.ngfiles.com/1572/1572356_medium.webp?f1';

    expect(track.artworkUrls.first,
        'https://aicon.ngfiles.com/1572/1572356_raw.png');
    expect(track.artworkUrls[1],
        'https://aicon.ngfiles.com/1572/1572356_raw.jpg');
    expect(track.artworkUrls[2],
        'https://aicon.ngfiles.com/1572/1572356_full.webp?f1');
  });
}
