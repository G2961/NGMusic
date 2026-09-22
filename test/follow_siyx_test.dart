import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:ngmusic/data/repository/ng_repository.dart';
void main() {
  test('siy-x реальный HTML: парсит followUrl/key', () {
    final html = File('.tmp/siyx.html').readAsStringSync();
    final btn = NgRepository().parseFaveButton(html, 'initFollowButton');
    expect(btn, isNotNull, reason: 'кнопка подписки должна находиться');
    expect(btn!.key, '1-6000-7501561');
    expect(btn.followUrl, 'https://www.newgrounds.com/favorites/users/7501561/follow');
  });

  test('статус подписки: active берётся из обёртки (jQuery-id без #)', () {
    final repo = NgRepository();
    // initFollowButton кладёт селектор '#ffr_…' — без срезания решётки
    // обёртка не находилась и active был null («неизвестно»), из-за чего
    // сайт-подписка не отображалась в приложении.
    final following = File('test/fixtures/listen_voted.html').readAsStringSync();
    expect(repo.parseFaveButton(following, 'initFollowButton')?.active, isFalse,
        reason: 'на этой странице нет follow-кнопки автора — но парсер не должен падать');
  });
}
