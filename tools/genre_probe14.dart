import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<Set<String>> genresOf(String q) async {
  final r = await http.get(
      Uri.parse('https://www.newgrounds.com/audio/browse?$q&inner=1'),
      headers: {'User-Agent': ua});
  return RegExp(r'class="detail-description"[^>]*>([^<]+)<')
      .allMatches(r.body)
      .map((m) => m.group(1)!.trim())
      .toSet();
}

Future<void> main() async {
  for (var n = 60; n <= 90; n++) {
    final g = await genresOf('genre=$n');
    if (g.isEmpty || g.length > 3) continue;
    print('$n -> $g');
  }
}
