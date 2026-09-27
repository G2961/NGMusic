import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<void> main() async {
  final r = await http.get(Uri.parse('https://www.newgrounds.com/audio'),
      headers: {'User-Agent': ua});
  final b = r.body;

  for (final m in RegExp(r'id="submenu-\d+"').allMatches(b).take(8)) {
    print('MENU: ${m.group(0)}');
  }

  final slugs = <String>{};
  for (final m
      in RegExp(r'/audio/browse/genre/([a-z0-9-]+)').allMatches(b)) {
    slugs.add(m.group(1)!);
  }
  print('slugs (${slugs.length}): ${slugs.toList()}');
}
