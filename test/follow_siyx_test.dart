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
}
