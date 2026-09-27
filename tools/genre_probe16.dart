import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<Set<String>> genresOf(int n) async {
  final r = await http.get(
      Uri.parse('https://www.newgrounds.com/audio/browse?genre=$n&inner=1'),
      headers: {'User-Agent': ua});
  return RegExp(r'class="detail-description"[^>]*>([^<]+)<')
      .allMatches(r.body)
      .map((m) => m.group(1)!.trim())
      .toSet();
}

Future<void> main() async {
  final found = <int, Set<String>>{};
  for (var n = 60; n <= 130; n++) {
    final g = await genresOf(n);
    if (g.isEmpty || g.length > 3) continue;
    found[n] = g;
    print('$n -> ${g.toList()}');
  }
  if (found.isEmpty) print('ничего в диапазоне 60..130');
}
