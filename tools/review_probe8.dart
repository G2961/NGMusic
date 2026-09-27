import 'dart:io';

import 'package:http/http.dart' as http;

const ua =
    'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';

Map<String, String> headers(String cookie) => {
      'User-Agent': ua,
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Cookie': cookie,
    };

Future<void> main(List<String> args) async {
  final trackId = args.isNotEmpty ? args.first : '1615369';
  final cookie = File(r'F:\vapecoding\ng2015\server\.ng_cookie')
      .readAsStringSync()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  final body = (await http.get(
          Uri.parse('https://www.newgrounds.com/audio/listen/$trackId'),
          headers: headers(cookie)))
      .body;

  print('create form: ${body.contains('/reviews/create/')}');

  final revIdx = body.indexOf('data-review-id="19684145"');
  if (revIdx > 0) {
    final headIdx = body.lastIndexOf('podtop', revIdx);
    print('\n=== FROM PODTOP TO MY CARD (${revIdx - headIdx} chars) ===');
    print(body
        .substring(headIdx, revIdx + 40)
        .replaceAll('\n', ' ')
        .replaceAll(RegExp(r'\s+'), ' '));
  }

  print('\n=== vote markers ===');
  for (final pat in ['data-my-vote', 'my_vote', 'already-voted', 'voted',
      'votebar-logged', 'sidestats']) {
    final idx = body.indexOf(pat);
    print('$pat: $idx');
    if (idx >= 0 && pat == 'data-my-vote') {
      print('  ${body.substring(idx - 100, idx + 200)}'.replaceAll('\n', ' '));
    }
  }
}
