import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Future<void> main() async {
  final r = await http.get(
      Uri.parse('https://www.newgrounds.com/audio/browse?inner=1'),
      headers: {'User-Agent': ua});
  final b = r.body;

  for (final m in RegExp(r'<select[^>]*name="([^"]+)"[^>]*>([\s\S]*?)</select>')
      .allMatches(b)) {
    final name = m.group(1)!;
    final options = RegExp(r'value="([^"]*)"')
        .allMatches(m.group(2)!)
        .map((o) => o.group(1)!)
        .toList();
    print('SELECT $name: ${options.length} опций: ${options.take(12).toList()}');
  }

  final i = b.indexOf('Voice Acting');
  print('\nVoice Acting idx=$i');
  if (i > 0) {
    print(b
        .substring((i - 200).clamp(0, i), (i + 200).clamp(0, b.length))
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' '));
  }
}
