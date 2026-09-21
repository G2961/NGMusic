// Разбор кнопки `favefollow` и пустышек `data-visual-link` — на сохранённых
// копиях реальной разметки, без сети.
//
// Почему это важно: в HTML NG всегда присутствуют ОБА состояния кнопки
// (`.favefollow-add` и `.favefollow-remove`), поэтому единственный признак
// «уже подписан / уже в избранном» — класс `active` на обёртке. Проверка по
// наличию `.following-user` возвращала true всегда, из-за чего статус подписки
// на странице артиста самопроизвольно переключался на «Подписан».

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
    // Ровно та ловушка, на которую попадал старый парсер.
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
    // Разметка с живой авторизованной страницы (2026): скрипта
    // initFavoriteButton больше нет, кнопка самодостаточна.
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

    // Кнопка подписки (follow-user) не путается с избранной.
    const followHtml =
        '<span class="favefollow-buttons active" id="ffr_ffr_6ab000_2">'
        '<a href="#" data-action="add" class="follow-user">FOLLOW</a></span>';
    final follow = repo.parseFaveButton(followHtml, 'initFavoriteButton');
    expect(follow, isNull); // это не favorite-кнопка
  });

  test('ответ fave: active опционален, errors — отказ', () {
    // Полный ответ (как раньше) — берём подтверждённое состояние.
    expect(repo.parseFaveResponse('{"active":true,"fave_type":2}', true), isTrue);
    expect(repo.parseFaveResponse('{"active":false}', false), isFalse);
    // Новый формат: success без active — считаем принятым запрошенным.
    expect(repo.parseFaveResponse('{"success":true,"count_key":"faves_1"}', true),
        isTrue);
    // Явные ошибки NG — отказ.
    expect(repo.parseFaveResponse('{"errors":["Illegal communication"]}', true),
        isNull);
    expect(repo.parseFaveResponse('not json', true), isNull);
  });

  test('id плейлистов берутся из data-visual-link, а не из ссылок', () {
    final html = _fixture('playlists_page.html');
    // Ссылок /playlists/view/ на странице нет — на них ориентировался
    // старый getUserPlaylists, поэтому синхронизация всегда давала пустой список.
    expect(html, isNot(contains('/playlists/view/')));

    final ids = repo.visualLinkIds(html, 21000);
    expect(ids.length, 30);
    expect(ids.first, '546239');
    expect(ids, contains('505922'));
    // Порядок разметки сохраняется.
    expect(ids.indexOf('544887'), 1);
    // Аудио-пустышек на этой странице нет.
    expect(repo.visualLinkIds(html, 3), isEmpty);
  });
}
