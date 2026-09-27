
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ngmusic/data/repository/ng_repository.dart';

String _fixture(String name) =>
    File('test/fixtures/$name').readAsStringSync();

void main() {
  final repo = NgRepository();

  test('обёртка с классом active означает «уже подписан»', () {
    final button = repo.parseFaveButton(
        _fixture('favefollow_active.html'), 'initFollowButton');

    expect(button, isNotNull);
    expect(button!.active, isTrue);
    expect(button.key, 'ff-g-gC4-EDoR');
    expect(button.userkey, isNotEmpty);
  });

  test('обёртка без active означает «не подписан», хотя remove-кнопка в DOM есть',
      () {
    final html = _fixture('favefollow_inactive.html');
    expect(html, contains('following-user'));
    expect(html, contains('favefollow-remove'));

    final button = repo.parseFaveButton(html, 'initFollowButton');
    expect(button, isNotNull);
    expect(button!.active, isFalse);
    expect(button.key, 'ff-g-gC4-g80qa');
  });

  test('запрос другой кнопки на той же странице не находится', () {
    final button = repo.parseFaveButton(
        _fixture('favefollow_active.html'), 'initFavoriteButton');
    expect(button, isNull);
  });

  test('новый формат без скрипта: ключ = id, userkey = глобальный uek', () {
    const html = "<script>PHP.set('uek', 'v2.TESTUSERKEY.sig');</script>"
        '<span class="favefollow-buttons" id="ffr_ffr_6ab07c91c8ab5_1">'
        '<span class="favefollow-add">'
        '<a href="" data-action="add" title="Add To Favorites" '
        'class="fave-item"><span>Add To Favorites</span></a></span>'
        '<span class="favefollow-remove">'
        '<a href="https://g2961.newgrounds.com//favorites" '
        'data-action="remove"></a></span></span>';

    final fav = repo.parseFaveButton(html, 'initFavoriteButton');
    expect(fav, isNotNull);
    expect(fav!.key, 'ffr_6ab07c91c8ab5_1');
    expect(fav.userkey, 'v2.TESTUSERKEY.sig');
    expect(fav.active, isFalse);

    const followHtml =
        '<span class="favefollow-buttons active" id="ffr_ffr_6ab000_2">'
        '<a href="#" data-action="add" class="follow-user">FOLLOW</a></span>';
    final follow = repo.parseFaveButton(followHtml, 'initFavoriteButton');
    expect(follow, isNull);
  });

  test('ответ fave: active опционален, errors — отказ', () {
    expect(repo.parseFaveResponse('{"active":true,"fave_type":2}', true), isTrue);
    expect(repo.parseFaveResponse('{"active":false}', false), isFalse);
    expect(repo.parseFaveResponse('{"success":true,"count_key":"faves_1"}', true),
        isTrue);
    expect(repo.parseFaveResponse('{"errors":["Illegal communication"]}', true),
        isNull);
    expect(repo.parseFaveResponse('not json', true), isNull);
  });

  test('id плейлистов берутся из data-visual-link, а не из ссылок', () {
    final html = _fixture('playlists_page.html');
    expect(html, isNot(contains('/playlists/view/')));

    final ids = repo.visualLinkIds(html, 21000);
    expect(ids.length, 30);
    expect(ids.first, '546239');
    expect(ids, contains('505922'));
    expect(ids.indexOf('544887'), 1);
    expect(repo.visualLinkIds(html, 3), isEmpty);
  });
}
