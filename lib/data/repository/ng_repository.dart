import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as htmlParser;
import 'package:html/dom.dart';

import '../model/track.dart';
import '../model/ng_user.dart';
import '../model/ng_review.dart';
import '../model/playlist.dart';
import 'ng_auth.dart';

class NgSiteDownException implements Exception {
  final int statusCode;
  final String url;

  NgSiteDownException(this.statusCode, this.url);

  @override
  String toString() => 'Newgrounds is down (HTTP $statusCode)';
}

class NgRepository {
  static const _baseUrl = 'https://www.newgrounds.com';
  static const _userAgent =
      'Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124 Mobile Safari/537.36';


  Future<List<Track>> getFeaturedTracks({int offset = 0, String? genre}) =>
      _parseTracks(offset == 0 && genre == null
          ? '$_baseUrl/audio/featured'
          : '$_baseUrl/audio/featured?'
              '${genre != null ? 'genre=$genre&' : ''}'
              '${offset > 0 ? 'offset=$offset&' : ''}'
              'inner=1');

  Future<List<Track>> getBrowseTracks({int offset = 0, String? genre}) =>
      _parseTracks('$_baseUrl/audio/browse?'
          '${genre != null ? 'genre=$genre&' : ''}'
          'offset=$offset&inner=1');

  Future<List<Track>> getPopularTracks({int offset = 0, String? genre}) =>
      _parseTracks('$_baseUrl/audio/popular?'
          '${genre != null ? 'genre=$genre&' : ''}'
          'offset=$offset&inner=1');

  Future<List<Track>> getTopRatedTracks({int offset = 0, String? genre}) =>
      _parseTracks('$_baseUrl/audio/browse?sort=score&interval=month'
          '${genre != null ? '&genre=$genre' : ''}'
          '&offset=$offset&inner=1');

  Future<List<Track>> getGenreTracks(String genreId, {int offset = 0}) =>
      getBrowseTracks(offset: offset, genre: genreId);

  Future<(List<Track>, String?)> getArtistTracksPage(
      String artist, {int page = 1}) async {
    final url =
        'https://${Uri.encodeComponent(artist.toLowerCase())}.newgrounds.com/audio?page=$page';
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': _userAgent,
          'Accept-Language': 'en-US,en;q=0.9',
          'X-Requested-With': 'XMLHttpRequest',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) return (<Track>[], null);

      final json = jsonDecode(response.body) as Map<String, dynamic>;

      final allHtml = ((json['items'] as Map?)?.values ?? [])
          .expand((v) => v is List ? v : [v])
          .cast<String>()
          .join('');

      final doc = htmlParser.parse(allHtml);
      final tracks = _parseArtistItems(doc, artist);

      final loadMore = json['load_more'] as String? ?? '';
      final nextUrl = RegExp(r'"(https://[^"]+page=\d+)"')
          .firstMatch(loadMore)
          ?.group(1);

      return (tracks, nextUrl);
    } catch (_) {
      return (<Track>[], null);
    }
  }

  Future<void> enrichTrack(Track track) async {
    try {
      final html = await _connectRaw('$_baseUrl/audio/listen/${track.id}');
      enrichFromHtml(track, html);
    } catch (_) {}
  }

  void enrichFromHtml(Track track, String html) {
    try {
      final match = RegExp(
        r'<script[^>]+id="preload-data"[^>]*>(.*?)</script>',
        dotAll: true,
      ).firstMatch(html);
      if (match == null) {
        _enrichFallback(track, html);
        return;
      }
      final data = jsonDecode(match.group(1)!) as Map<String, dynamic>;
      final song = data['song'] as Map<String, dynamic>?;
      if (song == null) {
        parseListenDetails(track, html);
        return;
      }

      final rawFilename = song['filename'] as String?;
      if (rawFilename != null && rawFilename.isNotEmpty) {
        final filename = rawFilename.startsWith('http')
            ? rawFilename
            : '${track.audioBaseUrl}$rawFilename';
        track.mp3Url ??= filename;
      }
      track.score   = song['score']?.toString()   ?? track.score;
      track.votes   = song['votes']?.toString()   ?? track.votes;
      track.listens = song['listens']?.toString() ?? track.listens;
      track.bpm     = song['bpm']?.toString()     ?? track.bpm;
      if ((track.genre.isEmpty) && song['genre'] != null) {
        track.genre = song['genre'] as String;
      }
      final icon = song['icon'] as String?;
      if (icon != null && icon.contains('ngfiles.com') &&
          !track.iconUrl.contains('ngfiles.com')) {
        track.iconUrl = icon;
      }
      parseListenDetails(track, html);
    } catch (_) {}
  }

  Future<List<Track>> searchTracks(String query, {int offset = 0}) async {
    final q = Uri.encodeQueryComponent(query.trim());
    final page = offset ~/ 24 + 1;
    final url = page == 1
        ? '$_baseUrl/search/conduct/audio?suitabilities=etma&c=3&terms=$q'
        : '$_baseUrl/search/conduct/audio?suitabilities=etma&c=3&terms=$q&page=$page';
    try {
      final doc = await _connect(url);
      return _parseSearchItems(doc);
    } catch (_) {
      return [];
    }
  }

  Future<Track?> getTrackById(String id) async {
    final clean = id.trim();
    if (int.tryParse(clean) == null) return null;
    try {
      final html = await _connectRaw('$_baseUrl/audio/listen/$clean');
      final track = trackFromListenPage(clean, html);
      if (track != null) enrichFromHtml(track, html);
      return track;
    } catch (_) {
      return null;
    }
  }

  Track? trackFromListenPage(String id, String html) {
    if (html.contains('The page you requested could not be found')) {
      return null;
    }
    final doc = htmlParser.parse(html);
    String? meta(String prop) => doc
        .querySelector('meta[property="$prop"]')
        ?.attributes['content'];

    final title = _decodeEntities(meta('og:title') ?? '');
    if (title.isEmpty) return null;
    final artist = _decodeEntities(
        doc.querySelector('.item-details-main h4 a')?.text.trim() ?? '');

    return Track(
      id: id,
      title: title,
      artist: artist.isEmpty ? 'Unknown' : artist,
      genre: '',
      iconUrl: meta('og:image') ?? '',
      duration: 0,
      audioType: 3,
      mp3Url: meta('og:audio'),
    );
  }

  Future<void> getTrackStats(Track track) => enrichTrack(track);

  Future<String?> getMp3Url(Track track) async {
    await enrichTrack(track);
    return track.mp3Url;
  }

  Future<NgUser?> getCurrentUser() async {
    final cookie = await NgAuth.getCookie();
    if (cookie == null || cookie.isEmpty) return null;
    try {
      final html = await _connectRawAuth('$_baseUrl/', cookie);
      final match =
          RegExp(r"PHP\.set\('activeuser',\s*(\{.*?\})\);").firstMatch(html);
      if (match == null) return null;

      final Map<String, dynamic> user;
      try {
        user = jsonDecode(match.group(1)!) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
      final username = (user['name'] as String?)?.trim();
      if (username == null || username.isEmpty) return null;

      await NgAuth.save(cookie: cookie, username: username);
      return await getUserProfile(username, cookie: cookie);
    } catch (_) {
      return null;
    }
  }

  Future<NgUser?> getUserProfile(String username, {String? cookie}) async {
    try {
      final url = 'https://${username.toLowerCase()}.newgrounds.com';
      final session = cookie ?? await NgAuth.getCookie();
      final html = (session != null && session.isNotEmpty)
          ? await _connectRawAuth(url, session)
          : await _connectRaw(url);
      final doc = htmlParser.parse(html);

      final avatar = doc
              .querySelector('meta[property="og:image"]')
              ?.attributes['content'] ??
          doc.querySelector('.user-icon img')?.attributes['src'] ??
          doc.querySelector('.usericon img')?.attributes['src'];

      String? age, gender, country, joinDate, level, exp;

      for (final dl in doc.querySelectorAll('dl.sidestats, dl.userdata, dl')) {
        final dts = dl.querySelectorAll('dt');
        final dds = dl.querySelectorAll('dd');
        for (var i = 0; i < dts.length && i < dds.length; i++) {
          final label = dts[i].text.trim().toLowerCase();
          final value = dds[i].text.trim();
          if (value.isEmpty) continue;
          if (label.contains('age')) age = value;
          if (label.contains('gender') || label.contains('sex')) gender = value;
          if (label.contains('country') || label.contains('location')) country = value;
          if (label.contains('joined') || label.contains('member since')) joinDate = value;
          if (label.contains('level')) level = value;
          if (label.contains('exp') || label.contains('experience')) exp = value;
        }
      }

      String? fans, audioCount;
      for (final btn in doc.querySelectorAll('a.user-header-button')) {
        final label = btn.querySelector('span')?.text.trim().toUpperCase() ?? '';
        final value = btn.querySelector('strong')?.text.trim() ?? '';
        if (label == 'FANS') fans = value;
        if (label == 'AUDIO') audioCount = value;
      }

      final isFollowing = parseFaveButton(html, 'initFollowButton')?.active;

      return NgUser(
        username: username,
        profileUrl: url,
        avatarUrl: avatar,
        age: age,
        gender: gender,
        country: country,
        joinDate: joinDate,
        level: level,
        exp: exp,
        fans: fans,
        audioCount: audioCount,
        isFollowing: isFollowing,
      );
    } catch (_) {
      return null;
    }
  }


  NgFaveButton? parseFaveButton(String html, String initFn) {
    if (initFn == 'initFollowButton') {
      final m = RegExp(
        'initFollowButton\\s*\\(\\s*"([^"]+)"\\s*,\\s*"([^"]+)"'
        '\\s*,\\s*\\{[^}]*"store"\\s*:\\s*"([^"]+)"'
        '[^}]*"destroy"\\s*:\\s*"([^"]+)"',
      ).firstMatch(html);
      if (m != null) {
        final domId = m.group(1)!.startsWith('#')
            ? m.group(1)!.substring(1)
            : m.group(1)!;
        final wrapper = RegExp(
          '<span class="favefollow-buttons([^"]*)" id="${RegExp.escape(domId)}"',
        ).firstMatch(html);
        return NgFaveButton(
          key: m.group(2)!,
          userkey: m.group(2)!,
          active: wrapper?.group(1)!.contains('active'),
          followUrl: m.group(3)!.replaceAll('\\/', '/'),
          unfollowUrl: m.group(4)!.replaceAll('\\/', '/'),
        );
      }
    }

    final init = RegExp(
      'ngutils\\.$initFn\\(\\s*["\' ]#([^"\' ]+)["\' ]\\s*,'
      '\\s*["\' ]([^"\' ]*)["\' ]\\s*,\\s*["\' ]([^"\' ]+)["\' ]\\s*\\)',
    ).firstMatch(html);
    if (init != null) {
      final domId = init.group(1)!;
      final wrapper = RegExp(
        '<span class="favefollow-buttons([^"]*)" id="${RegExp.escape(domId)}"',
      ).firstMatch(html);

      return NgFaveButton(
        key: init.group(3)!,
        userkey: init.group(2)!,
        active: wrapper?.group(1)!.contains('active'),
      );
    }

    final wrapper = RegExp(
      r'<span class="favefollow-buttons([^"]*)" id="(ffr_([^"]+))"',
    ).firstMatch(html);
    if (wrapper == null) return null;

    final block = _blockAround(html, wrapper.group(2)!);
    final isFavoriteKind = block.contains('fave-item') ||
        block.contains('Add To Favorites');
    final isFollowKind =
        block.contains('follow-user') || block.contains('FOLLOW');
    final want = initFn == 'initFavoriteButton' ? isFavoriteKind : isFollowKind;
    if (!want) return null;

    final uek =
        RegExp(r"PHP\.set\('uek',\s*'([^']*)'\)").firstMatch(html)?.group(1) ??
            RegExp(r'name="userkey" value="([^"]+)"')
                .firstMatch(html)
                ?.group(1) ??
            '';

    return NgFaveButton(
      key: wrapper.group(3)!,
      userkey: uek,
      active: wrapper.group(1)!.contains('active'),
    );
  }

  String _blockAround(String html, String marker) {
    final i = html.indexOf(marker);
    if (i < 0) return '';
    final from = i - 300 < 0 ? 0 : i - 300;
    final to = i + 700 < html.length ? i + 700 : html.length;
    return html.substring(from, to);
  }

  Future<bool?> _postFave({
    required String origin,
    required String type,
    required bool add,
    required NgFaveButton button,
    required String cookie,
    required String referer,
    String? ngDesign,
    String? csrfToken,
  }) async {
    final url =
        '$origin/favorites/$type/${add ? 'add' : 'remove'}/${button.key}';
    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'User-Agent': _userAgent,
              'Cookie': cookie,
              'X-Requested-With': 'XMLHttpRequest',
              if (csrfToken != null && csrfToken.isNotEmpty)
                'X-CSRF-TOKEN': csrfToken,
              'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
              'Accept': 'application/json, text/javascript, */*; q=0.01',
              'Referer': referer,
              'Origin': origin,
            },
            body: 'userkey=${Uri.encodeQueryComponent(button.userkey)}'
                '${ngDesign != null ? '&___ng_design=${Uri.encodeQueryComponent(ngDesign)}' : ''}',
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('[ng] $url -> ${response.statusCode} ${response.body}');
        return null;
      }
      debugPrint('[ng] fave POST -> 200, тело: ${response.body.length > 400
          ? response.body.substring(0, 400)
          : response.body}');
      return parseFaveResponse(response.body, add);
    } catch (e) {
      debugPrint('[ng] $url failed: $e');
      return null;
    }
  }

  bool? parseFaveResponse(String body, bool requested) {
    try {
      final json = jsonDecode(body);
      if (json is! Map) return null;
      if (json['errors'] != null || json['error'] != null) {
        debugPrint('[ng] fave отклонён: $body');
        return null;
      }
      final active = json['active'];
      if (active is bool) return active;
      return requested;
    } catch (_) {
      return null;
    }
  }

  Future<NgFaveButton?> _favoriteButton(
      String trackId, String cookie, String pageHtml) async {
    final direct = parseFaveButton(pageHtml, 'initFavoriteButton');
    if (direct != null) {
      debugPrint('[ng] fav-кнопка найдена прямо на странице трека');
      return direct;
    }

    final pid = RegExp(r'projects/audio/(\d+)/load-component/users')
            .firstMatch(pageHtml)
            ?.group(1) ??
        RegExp(r'data-users-and-credits-for="(\d+)"')
            .firstMatch(pageHtml)
            ?.group(1);
    debugPrint('[ng] fav: кнопки на странице нет (projectId=$pid)');
    if (pid == null) return null;
    try {
      final comp = await _connectRawAuth(
          '$_baseUrl/projects/audio/$pid/load-component/users', cookie);
      debugPrint('[ng] fav: компонент ${comp.length} байт, '
          'initFavoriteButton есть: ${comp.contains('initFavoriteButton')}, '
          'favefollow: ${comp.contains('favefollow')}');
      final button = parseFaveButton(comp, 'initFavoriteButton');
      if (button == null) {
        debugPrint('[ng] fav: parse не сработал, '
            'фрагмент: ${comp.substring(0, comp.length < 400 ? comp.length : 400)}');
      }
      return button;
    } catch (e) {
      debugPrint('[ng] fav: компонент не скачался: $e');
      return null;
    }
  }

  Future<bool?> setFavorite(String trackId, bool add) async {
    final cookie = await NgAuth.getCookie();
    if (cookie == null || cookie.isEmpty) return null;

    final pageUrl = '$_baseUrl/audio/listen/$trackId';
    try {
      final pageResp = await _fetch(pageUrl, cookie: cookie);
      if (pageResp.statusCode != 200) {
        debugPrint('[ng] fav: страница трека -> ${pageResp.statusCode}');
        return null;
      }
      final html = pageResp.body;
      final cookieForPost = _mergeSetCookie(cookie, pageResp.headers['set-cookie']);
      final button = await _favoriteButton(trackId, cookieForPost, html);
      if (button == null) {
        debugPrint('[ng] кнопки избранного нет на $pageUrl — '
            'скорее всего, сессия не авторизована');
        return null;
      }
      if (button.active == add) return add;

      final response = await http
          .post(
            Uri.parse('$_baseUrl/favorites/audio/$trackId/favorite'),
            headers: {
              'User-Agent': _userAgent,
              'Cookie': cookieForPost,
              'X-Requested-With': 'XMLHttpRequest',
              'X-CSRF-TOKEN': _csrfFrom(html) ?? '',
              'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
              'Accept': 'application/json, text/javascript, */*; q=0.01',
              'Referer': pageUrl,
            },
            body: add ? '___ng_design=2015' : '',
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('[ng] favorite POST -> ${response.statusCode} '
            '${response.body}');
        return null;
      }
      debugPrint('[ng] favorite POST -> 200 ${response.body}');
      return parseFaveResponse(response.body, add);
    } catch (e) {
      debugPrint('[ng] setFavorite($trackId, $add) failed: $e');
      return null;
    }
  }

  String _mergeSetCookie(String cookie, String? setCookie) {
    if (setCookie == null || setCookie.isEmpty) return cookie;
    final jar = <String, String>{};
    for (final part in cookie.split('; ')) {
      final i = part.indexOf('=');
      if (i > 0) jar[part.substring(0, i)] = part.substring(i + 1);
    }
    final merged = setCookie;
    final re = RegExp(r'[^,; ]+=[^;,]*');
    for (final m in re.allMatches(merged)) {
      final pair = m.group(0)!;
      final i = pair.indexOf('=');
      if (i <= 0) continue;
      final name = pair.substring(0, i);
      final value = pair.substring(i + 1);
      if (value.contains(',')) continue;
      jar[name] = pair;
    }
    return jar.entries.map((e) => e.value).join('; ');
  }

  String? _csrfFrom(String html) =>
      RegExp(r'<meta name="csrf-token" content="([^"]+)"')
          .firstMatch(html)
          ?.group(1);

  Future<bool?> getFavoriteStatus(String trackId) async {
    final cookie = await NgAuth.getCookie();
    if (cookie == null || cookie.isEmpty) return null;
    try {
      final html =
          await _connectRawAuth('$_baseUrl/audio/listen/$trackId', cookie);
      final button = await _favoriteButton(trackId, cookie, html);
      return button?.active;
    } catch (_) {
      return null;
    }
  }

  Future<bool?> setFollow(String artistUsername, bool add) async {
    final cookie = await NgAuth.getCookie();
    if (cookie == null || cookie.isEmpty) return null;

    final startUrl = 'https://${artistUsername.toLowerCase()}.newgrounds.com';
    try {
      final page = await _fetch(startUrl, cookie: cookie);
      if (page.statusCode != 200) return null;

      final button = parseFaveButton(page.body, 'initFollowButton');
      if (button == null) {
        debugPrint('[ng] кнопки подписки нет на $startUrl — '
            'скорее всего, сессия не авторизована');
        return null;
      }
      if (button.active == add) return add;

      final cookieForPost =
          _mergeSetCookie(cookie, page.headers['set-cookie']);

      if (button.followUrl != null) {
        final followReferer =
            page.request?.url?.toString() ?? '$startUrl/';
        return _postFollow(
          url: (add ? button.followUrl : button.unfollowUrl) ?? button.followUrl!,
          userkey: button.userkey,
          add: add,
          cookie: cookieForPost,
          referer: followReferer,
          csrfToken: _csrfFrom(page.body),
        );
      }

      final finalUri = page.request?.url ?? Uri.parse(startUrl);
      final origin = '${finalUri.scheme}://${finalUri.host}';

      return _postFave(
        origin: origin,
        type: 'follow',
        add: add,
        button: button,
        cookie: cookieForPost,
        referer: '$origin/',
        csrfToken: _csrfFrom(page.body),
      );
    } catch (e) {
      debugPrint('[ng] setFollow($artistUsername, $add) failed: $e');
      return null;
    }
  }

  Future<bool?> _postFollow({
    required String url,
    required String userkey,
    required bool add,
    required String cookie,
    required String referer,
    String? csrfToken,
  }) async {
    try {
      final uri = Uri.parse(url);

      final headers = {
        'User-Agent': _userAgent,
        'Cookie': cookie,
        'X-Requested-With': 'XMLHttpRequest',
        if (csrfToken != null && csrfToken.isNotEmpty)
          'X-CSRF-TOKEN': csrfToken,
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Referer': referer,
      };

      final body =
          'userkey=${Uri.encodeQueryComponent(userkey)}&___ng_design=2015';
      final client = http.Client();
      final response = await client
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 15));
      client.close();

      debugPrint('[ng] follow POST -> ${response.statusCode} '
          '${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
      if (response.statusCode == 200) {
        return parseFaveResponse(response.body, add);
      }
      return null;
    } catch (e) {
      debugPrint('[ng] follow $url failed: $e');
      return null;
    }
  }

  Future<bool?> getFollowStatus(String artistUsername) async {
    final cookie = await NgAuth.getCookie();
    if (cookie == null || cookie.isEmpty) return null;
    try {
      final html = await _connectRawAuth(
          'https://${artistUsername.toLowerCase()}.newgrounds.com', cookie);
      return parseFaveButton(html, 'initFollowButton')?.active;
    } catch (_) {
      return null;
    }
  }


  int? parseMyVote(String html) {
    final m = RegExp(
      'id="votebar-\\d+"\\s+value="(\\d+)"\\s+checked',
    ).firstMatch(html);
    return m == null ? null : int.tryParse(m.group(1)!);
  }

  String _decodeEntities(String s) => s
      .replaceAll('&amp;', '&')
      .replaceAll('&#039;', "'")
      .replaceAll('&#39;', "'")
      .replaceAll('&quot;', '"')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&nbsp;', ' ');

  String _fmtReviewDate(String s) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
    if (m == null) return s;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final mi = int.tryParse(m.group(2)!) ?? 0;
    if (mi < 1 || mi > 12) return s;
    return '${months[mi - 1]} ${int.tryParse(m.group(3)!) ?? 0}, ${m.group(1)}';
  }

  List<NgReview> parseReviews(String html) {
    final out = <NgReview>[];
    final cards = RegExp(
            r'<div\s+class="pod-body review"[\s\S]{0,120}?data-review-id="(\d+)">')
        .allMatches(html)
        .toList();
    for (var i = 0; i < cards.length; i++) {
      final start = cards[i].end;
      final end = i + 1 < cards.length ? cards[i + 1].start : html.length;
      final block = html.substring(start, end);

      final user = RegExp(
              r'<a href="https://([a-z0-9-]+)\.newgrounds\.com"[^>]*title="([^"]*)"')
          .firstMatch(block);
      final icon = RegExp(r'<image href="([^"]+)"').firstMatch(block);
      final time = RegExp(r'<time[^>]*>([^<]+)</time>').firstMatch(block);
      final score = RegExp(r'title="Score: ([\d.]+)').firstMatch(block);
      final flag =
          RegExp(r'class="ngicon-25-flag"[^>]*href="([^"]+)"').firstMatch(block);
      final body = RegExp(r'<div class="review-body[^"]*"[^>]*>([\s\S]*?)</div>')
          .firstMatch(block);

      NgReviewResponse? response;
      final respBlock = RegExp(
              r'<div class="authresponse"[^>]*>([\s\S]*?)</div>\s*</div>')
          .firstMatch(block);
      if (respBlock != null) {
        final seg = respBlock.group(1)!;
        final rAuthor = RegExp(r'<a href="https://([a-z0-9-]+)\.newgrounds\.com">([^<]+)</a>')
            .firstMatch(seg);
        final rIcon = RegExp(r'<image href="([^"]+)"').firstMatch(seg);
        final rBody = RegExp(r'<p>([\s\S]*?)</p>\s*</div>\s*$')
                .firstMatch(seg) ??
            RegExp(r'responds:\s*</span>[\s\S]*?<p>([\s\S]*?)</p>')
                .firstMatch(seg);
        response = NgReviewResponse(
          authorSlug: rAuthor?.group(1) ?? '',
          author: _decodeEntities(rAuthor?.group(2) ?? ''),
          avatarUrl: rIcon?.group(1) ?? '',
          body: _decodeEntities(
              rBody?.group(1)?.replaceAll(RegExp(r'<[^>]+>'), ' ').trim() ?? ''),
        );
      }

      out.add(NgReview(
        id: cards[i].group(1)!,
        authorSlug: user?.group(1) ?? '',
        author: _decodeEntities(user?.group(2) ?? 'Anonymous'),
        avatarUrl: icon?.group(1) ?? '',
        date: _fmtReviewDate(_decodeEntities(time?.group(1)?.trim() ?? '')),
        score: double.tryParse(score?.group(1) ?? '') ?? 0,
        flagUrl: flag?.group(1) ?? '',
        response: response,
        body: _decodeEntities(
            body?.group(1)?.replaceAll(RegExp(r'<[^>]+>'), ' ').trim() ?? ''),
      ));
    }
    return out;
  }

  Future<ReviewsPage?> getReviews(String trackId,
      {String sort = 'date', int page = 1}) async {
    final s = sort == 'score' ? 'score' : 'date';
    try {
      final url = '$_baseUrl/reviews/portal/$trackId/3/$s/$page';
      final cookie = await NgAuth.getCookie();
      final html = (cookie != null && cookie.isNotEmpty)
          ? await _connectRawAuth(url, cookie)
          : await _connectRaw(url);
      final pages = RegExp(r'Page</span>\s*\d+\s*of\s*(\d+)')
              .firstMatch(html)?.group(1);
      return ReviewsPage(
        items: parseReviews(html),
        page: page,
        pages: pages == null ? 1 : int.tryParse(pages) ?? 1,
      );
    } catch (e) {
      debugPrint('[ng] getReviews($trackId) failed: $e');
      return null;
    }
  }

  Future<VoteResult?> voteTrack(String trackId, int vote) async {
    final cookie = await NgAuth.getCookie();
    if (cookie == null || cookie.isEmpty) return null;
    final v = vote.clamp(0, 10);

    final pageUrl = '$_baseUrl/audio/listen/$trackId';
    try {
      final key = await _fetchUserkey(cookie, trackId: trackId);
      if (key == null) {
        debugPrint('[ng] voteTrack: нет userkey — сессия не авторизована');
        return null;
      }
      final res = await http
          .post(
            Uri.parse('$_baseUrl/content/vote/$trackId/3'),
            headers: {
              'User-Agent': _userAgent,
              'Cookie': cookie,
              'X-Requested-With': 'XMLHttpRequest',
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
              'Accept': 'application/json, text/javascript, */*; q=0.01',
              'Referer': pageUrl,
            },
            body: 'show_fields=1'
                '&userkey=${Uri.encodeQueryComponent(key)}'
                '&vote=$v',
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode != 200) {
        debugPrint('[ng] vote -> ${res.statusCode} ${res.body}');
        return null;
      }
      final parsed = _parseVoteResponse(res.body);
      await NgAuth.saveMyVote(trackId, v);
      return parsed;
    } catch (e) {
      debugPrint('[ng] voteTrack($trackId, $vote) failed: $e');
      return null;
    }
  }

  VoteResult? parseVoteResponsePublic(String body) =>
      _parseVoteResponse(body);

  VoteResult? _parseVoteResponse(String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map) return null;
      final side = json['sidestats'];
      if (side is! String) {
        return null;
      }
      final score =
          RegExp(r'id="score_number"[^>]*>([\d.]+)<').firstMatch(side);
      final votes =
          RegExp(r'<dt>Votes</dt>\s*<dd>([\d,]+)<').firstMatch(side);
      final waitingM = RegExp(r'Waiting for (\d+) more').firstMatch(side);
      return VoteResult(
        score: double.tryParse(score?.group(1) ?? ''),
        votes: votes == null ? null : int.tryParse(votes.group(1)!.replaceAll(',', '')),
        waiting: waitingM != null,
        pendingVotes:
            waitingM == null ? null : int.tryParse(waitingM.group(1)!),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> postReview(
      String trackId, String text, int stars) async {
    final cookie = await NgAuth.getCookie();
    if (cookie == null || cookie.isEmpty) return 'not logged in';

    final pageUrl = '$_baseUrl/audio/listen/$trackId';
    try {
      final html = await _connectRawAuth(pageUrl, cookie);
      final key = _userkeyFrom(html);
      if (key == null) {
        debugPrint('[ng] postReview: нет userkey — сессия не авторизована');
        return 'not logged in';
      }

      final res = await http
          .post(
            Uri.parse('$_baseUrl/reviews/create/$trackId/3'),
            headers: {
              'User-Agent': _userAgent,
              'Cookie': cookie,
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
              'Referer': pageUrl,
            },
            body: 'userkey=${Uri.encodeQueryComponent(key)}'
                '&generic_id=$trackId'
                '&type_id=3'
                '&vote=${stars.clamp(0, 10)}'
                '&body=${Uri.encodeQueryComponent(text)}',
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 ||
          (res.statusCode >= 300 && res.statusCode < 400)) {
        final err = RegExp(r'class="[^"]*(error|alert)[^"]*"[^>]*>([^<]+)')
            .firstMatch(res.body)?.group(2);
        if (err == null) {
          await NgAuth.saveMyReview(trackId, '', text, stars);
          await NgAuth.saveMyVote(trackId, stars);
          return null;
        }
        return _decodeEntities(err.trim());
      }
      debugPrint('[ng] review -> ${res.statusCode} ${res.body}');
      return 'NG ${res.statusCode}';
    } catch (e) {
      debugPrint('[ng] postReview($trackId) failed: $e');
      return 'network error';
    }
  }

  Future<NgReview?> getMyReview(String trackId) async {
    final cookie = await NgAuth.getCookie();
    if (cookie == null || cookie.isEmpty) return null;
    try {
      final html = await _connectRawAuth('$_baseUrl/audio/listen/$trackId', cookie);
      final review = parseMyReview(html);
      if (review != null) {
        await NgAuth.saveMyReview(trackId, review.id, review.body,
            review.hasScore ? (review.score * 2).round() : null);
      }
      final siteVote = parseMyVote(html);
      if (siteVote != null) {
        await NgAuth.saveMyVote(trackId, siteVote.clamp(0, 10));
      }
      return review;
    } catch (e) {
      debugPrint('[ng] getMyReview($trackId) failed: $e');
      return null;
    }
  }

  NgReview? parseMyReview(String html) {
    final editLink =
        RegExp(r'href="/reviews/edit/(\d+)"').firstMatch(html);
    if (editLink == null) return null;
    final reviewId = editLink.group(1)!;

    final cardStart = html.lastIndexOf('data-review-id="$reviewId"');
    if (cardStart < 0) return null;
    final from = html.lastIndexOf('<div', cardStart);
    var seg = html.substring(from, html.length);
    final reactions = seg.indexOf('review_reactions');
    if (reactions > 0) seg = seg.substring(0, reactions);

    final scoreM = RegExp(r'title="Score: ([\d.]+)').firstMatch(seg);
    final timeM = RegExp(r'<time[^>]*>([^<]+)</time>').firstMatch(seg);
    final bodyM = RegExp(r'<div class="review-body[^"]*"[^>]*>([\s\S]*?)</div>')
        .firstMatch(seg);

    return NgReview(
      id: reviewId,
      author: 'You',
      authorSlug: '',
      avatarUrl: '',
      date: _decodeEntities(timeM?.group(1)?.trim() ?? ''),
      score: double.tryParse(scoreM?.group(1) ?? '') ?? 0,
      body: _decodeEntities(
          bodyM?.group(1)?.replaceAll(RegExp(r'<[^>]+>'), ' ').trim() ?? ''),
    );
  }

  Future<String?> editReview(
      String reviewId, String trackId, String text, int stars) async {
    final cookie = await NgAuth.getCookie();
    if (cookie == null || cookie.isEmpty) return 'not logged in';

    final pageUrl = '$_baseUrl/reviews/edit/$reviewId';
    try {
      final formHtml = await _connectRawAuth(pageUrl, cookie);
      final key = _userkeyFrom(formHtml);
      if (key == null) {
        debugPrint('[ng] editReview: нет userkey — сессия не авторизована');
        return 'not logged in';
      }

      final res = await http
          .post(
            Uri.parse(pageUrl),
            headers: {
              'User-Agent': _userAgent,
              'Cookie': cookie,
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
              'Referer': pageUrl,
            },
            body: 'userkey=${Uri.encodeQueryComponent(key)}'
                '&generic_id=$trackId'
                '&type_id=3'
                '&vote=${stars.clamp(0, 10)}'
                '&body=${Uri.encodeQueryComponent(text)}',
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 ||
          (res.statusCode >= 300 && res.statusCode < 400)) {
        final err = RegExp(r'class="[^"]*(error|alert)[^"]*"[^>]*>([^<]+)')
            .firstMatch(res.body)?.group(2);
        if (err == null) return null;
        return _decodeEntities(err.trim());
      }
      debugPrint('[ng] editReview -> ${res.statusCode} ${res.body}');
      return 'NG ${res.statusCode}';
    } catch (e) {
      debugPrint('[ng] editReview($reviewId) failed: $e');
      return 'network error';
    }
  }

  Future<String?> postResponse(String reviewId, String text) async {
    final cookie = await NgAuth.getCookie();
    if (cookie == null || cookie.isEmpty) return 'not logged in';

    final pageUrl = '$_baseUrl/reviews/responses/create/$reviewId';
    try {
      final formHtml = await _connectRawAuth(pageUrl, cookie);
      if (!formHtml.contains('response_form_$reviewId')) {
        return 'not your track';
      }
      final key = _userkeyFrom(formHtml);
      if (key == null) {
        debugPrint('[ng] postResponse: нет userkey — сессия не авторизована');
        return 'not logged in';
      }

      final res = await http
          .post(
            Uri.parse(pageUrl),
            headers: {
              'User-Agent': _userAgent,
              'Cookie': cookie,
              'Content-Type':
                  'application/x-www-form-urlencoded; charset=UTF-8',
              'Referer': pageUrl,
            },
            body: 'userkey=${Uri.encodeQueryComponent(key)}'
                '&body=${Uri.encodeQueryComponent(text)}',
          )
          .timeout(const Duration(seconds: 15));

      if (res.statusCode == 200 ||
          (res.statusCode >= 300 && res.statusCode < 400)) {
        final err = RegExp(r'class="[^"]*(error|alert)[^"]*"[^>]*>([^<]+)')
            .firstMatch(res.body)?.group(2);
        if (err == null) return null;
        return _decodeEntities(err.trim());
      }
      debugPrint('[ng] postResponse -> ${res.statusCode} ${res.body}');
      return 'NG ${res.statusCode}';
    } catch (e) {
      debugPrint('[ng] postResponse($reviewId) failed: $e');
      return 'network error';
    }
  }

  Future<String?> deleteReview(String reviewId, String trackId) async {
    final cookie = await NgAuth.getCookie();
    if (cookie == null || cookie.isEmpty) return 'not logged in';
    try {
      final res = await _fetch('$_baseUrl/reviews/delete/$reviewId',
          cookie: cookie);
      if (res.statusCode == 200 || (res.statusCode >= 300 && res.statusCode < 400)) {
        await NgAuth.clearMyReview(trackId);
        await NgAuth.clearMyVote(trackId);
        return null;
      }
      debugPrint('[ng] deleteReview -> ${res.statusCode}');
      return 'NG ${res.statusCode}';
    } catch (e) {
      debugPrint('[ng] deleteReview($reviewId) failed: $e');
      return 'network error';
    }
  }


  String? _userkeyFrom(String html) =>
      RegExp(r"PHP\.set\('uek',\s*'([^']*)'").firstMatch(html)?.group(1) ??
      RegExp(r'name="userkey" value="([^"]+)"').firstMatch(html)?.group(1);

  Future<String?> _fetchUserkey(String cookie, {String? trackId}) async {
    if (trackId != null) {
      try {
        final html = await _connectRawAuth(
            '$_baseUrl/playlists/addentry/$trackId/3?isAjaxRequest=1', cookie);
        final key = _userkeyFrom(html);
        if (key != null) return key;
      } catch (_) {}
    }
    try {
      return _userkeyFrom(await _connectRawAuth('$_baseUrl/', cookie));
    } catch (_) {
      return null;
    }
  }

  List<String> visualLinkIds(String html, int type) {
    final out = <String>[];
    for (final m
        in RegExp(r'data-visual-link="\[(\d+),(\d+)\]"').allMatches(html)) {
      if (m.group(1) != '$type') continue;
      final id = m.group(2)!;
      if (!out.contains(id)) out.add(id);
    }
    return out;
  }

  Future<Map<String, String>> _fetchVisualLinks(
    String origin,
    int type,
    List<String> ids,
    String? cookie,
  ) async {
    final out = <String, String>{};
    for (var i = 0; i < ids.length; i += 25) {
      var end = i + 25;
      if (end > ids.length) end = ids.length;
      final batch = ids.sublist(i, end).map((id) => [type, int.parse(id)]).toList();
      try {
        final response = await http
            .post(
              Uri.parse('$origin/visual-links-fetch'),
              headers: {
                'User-Agent': _userAgent,
                if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
                'X-Requested-With': 'XMLHttpRequest',
                'Content-Type':
                    'application/x-www-form-urlencoded; charset=UTF-8',
                'Accept': 'application/json, text/javascript, */*; q=0.01',
                'Referer': '$origin/',
              },
              body: 'ids=${Uri.encodeQueryComponent(jsonEncode(batch))}'
                  '&include_all_suitabilities=0',
            )
            .timeout(const Duration(seconds: 20));
        if (response.statusCode != 200) {
          debugPrint('[ng] visual-links-fetch -> ${response.statusCode}');
          continue;
        }
        final json = jsonDecode(response.body);
        if (json is! Map) continue;
        final partials = json['partials'];
        if (partials is! Map) continue;
        final byId = partials['$type'];
        if (byId is! Map) continue;
        byId.forEach((k, v) {
          if (v is String) out['$k'] = v;
        });
      } catch (e) {
        debugPrint('[ng] visual-links-fetch failed: $e');
      }
    }
    return out;
  }

  Future<List<NgCloudPlaylist>> getUserPlaylists(String username) async {
    final cookie = await NgAuth.getCookie();
    if (cookie == null || cookie.isEmpty) return [];
    final origin = 'https://${username.toLowerCase()}.newgrounds.com';

    final ids = <String>[];
    for (var page = 1; page <= 30; page++) {
      final url =
          page == 1 ? '$origin/playlists' : '$origin/playlists?page=$page';
      final String html;
      try {
        html = await _connectRawAuth(url, cookie);
      } catch (_) {
        break;
      }
      final fresh =
          visualLinkIds(html, 21000).where((id) => !ids.contains(id)).toList();
      if (fresh.isEmpty) break;
      ids.addAll(fresh);
    }
    if (ids.isEmpty) return [];

    final partials = await _fetchVisualLinks(origin, 21000, ids, cookie);
    final out = <NgCloudPlaylist>[];
    for (final id in ids) {
      final html = partials[id];
      if (html == null) continue;
      final doc = htmlParser.parse(html);
      final a = doc.querySelector('a.item-playlist') ?? doc.querySelector('a');
      final name = (doc.querySelector('h4')?.text ?? '').trim();
      if (name.isEmpty) continue;
      out.add(NgCloudPlaylist(
        id: id,
        name: name,
        url: a?.attributes['href'],
        entries: int.tryParse(a?.attributes['data-total-entries'] ?? ''),
        iconUrl: doc.querySelector('.item-icon img')?.attributes['src'],
      ));
    }
    return out;
  }

  Future<List<Track>> getNgPlaylistTracks(String playlistId) async {
    final cookie = await NgAuth.getCookie();
    final hasCookie = cookie != null && cookie.isNotEmpty;

    final ids = <String>[];
    for (var page = 1; page <= 20; page++) {
      final url = page == 1
          ? '$_baseUrl/playlist/$playlistId'
          : '$_baseUrl/playlist/$playlistId?page=$page';
      final String html;
      try {
        html = hasCookie
            ? await _connectRawAuth(url, cookie)
            : await _connectRaw(url);
      } catch (_) {
        break;
      }
      final fresh =
          visualLinkIds(html, 3).where((id) => !ids.contains(id)).toList();
      if (fresh.isEmpty) break;
      ids.addAll(fresh);
    }
    if (ids.isEmpty) return [];

    final partials = await _fetchVisualLinks(_baseUrl, 3, ids, cookie);
    final list = ids
        .map((id) => partials[id] ?? '')
        .where((s) => s.isNotEmpty)
        .join();
    if (list.isEmpty) return [];
    return _parseSearchItems(
        htmlParser.parse('<ul class="itemlist">$list</ul>'));
  }

  Future<List<NgCloudPlaylist>> getAllNgPlaylists(
      String trackId, String username) async {
    final results = await Future.wait([
      if (username.isNotEmpty && username != 'unknown')
        getUserPlaylists(username)
      else
        Future.value(<NgCloudPlaylist>[]),
      getNgPlaylists(trackId),
    ]);

    final byId = <String, NgCloudPlaylist>{};
    for (final list in results) {
      for (final pl in list) {
        byId.putIfAbsent(pl.id, () => pl);
      }
    }
    return byId.values.toList();
  }

  Future<List<NgCloudPlaylist>> getNgPlaylists(String trackId) async {
    try {
      final cookie = await NgAuth.getCookie();
      if (cookie == null || cookie.isEmpty) return [];
      final doc = htmlParser.parse(await _connectRawAuth(
          '$_baseUrl/playlists/addentry/$trackId/3?isAjaxRequest=1', cookie));
      final select = doc.querySelector('select[name="playlist_id"]');
      if (select == null) return [];
      return select
          .querySelectorAll('option')
          .map((opt) => NgCloudPlaylist(
                id: opt.attributes['value'] ?? '',
                name: opt.text.trim(),
              ))
          .where((p) => p.id.isNotEmpty && p.name.isNotEmpty)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<String?> _addEntry(
    String trackId, {
    required String cookie,
    String? playlistId,
    String? newPlaylistName,
  }) async {
    final userkey = await _fetchUserkey(cookie, trackId: trackId);
    if (userkey == null) {
      debugPrint('[ng] addentry: не удалось получить userkey');
      return null;
    }
    final body = {
      'id': trackId,
      'type': '3',
      'userkey': userkey,
      if (playlistId != null) 'playlist_id': playlistId,
      if (newPlaylistName != null) 'title': newPlaylistName,
    };
    try {
      final response = await http
          .post(
            Uri.parse('$_baseUrl/playlists/addentry'),
            headers: {
              'User-Agent': _userAgent,
              'Cookie': cookie,
              'X-Requested-With': 'XMLHttpRequest',
              'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
              'Accept': 'application/json, text/javascript, */*; q=0.01',
              'Referer': '$_baseUrl/audio/listen/$trackId',
            },
            body: body.entries
                .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
                .join('&'),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode != 200) {
        debugPrint('[ng] addentry -> ${response.statusCode} '
            '${response.body.substring(0, response.body.length.clamp(0, 300))}');
        return null;
      }
      return RegExp(r'/playlist/(\d+)').firstMatch(response.body)?.group(1) ??
          playlistId;
    } catch (e) {
      debugPrint('[ng] addentry failed: $e');
      return null;
    }
  }

  Future<bool> addToNgPlaylist(
    String trackId, {
    String? playlistId,
    String? newPlaylistName,
  }) async {
    final cookie = await NgAuth.getCookie();
    if (cookie == null || cookie.isEmpty) return false;
    final id = await _addEntry(trackId,
        cookie: cookie,
        playlistId: playlistId,
        newPlaylistName: newPlaylistName);
    return id != null;
  }

  Future<String?> createNgPlaylist(String name, {String? seedTrackId}) async {
    final cookie = await NgAuth.getCookie();
    if (cookie == null || cookie.isEmpty) return null;

    var seed = seedTrackId;
    final seeded = seed != null && seed.isNotEmpty;
    if (!seeded) {
      final featured = await getFeaturedTracks();
      if (featured.isEmpty) {
        debugPrint('[ng] createNgPlaylist: не нашли трек-затравку');
        return null;
      }
      seed = featured.first.id;
    }

    final id = await _addEntry(seed, cookie: cookie, newPlaylistName: name);
    if (id == null) return null;
    if (!seeded) await removeFromNgPlaylist(id, seed);
    return id;
  }

  Future<bool> removeFromNgPlaylist(String playlistId, String trackId) async {
    final cookie = await NgAuth.getCookie();
    if (cookie == null || cookie.isEmpty) return false;
    final editUrl = '$_baseUrl/playlists/edit/$playlistId';
    try {
      final html = await _connectRawAuth(editUrl, cookie);
      final userkey = _userkeyFrom(html);
      if (userkey == null) return false;

      String? entryId;
      for (final m in RegExp(
              r'data-id="(\d+)"[^>]*data-visual-link="\[3,(\d+)\]"')
          .allMatches(html)) {
        if (m.group(2) == trackId) {
          entryId = m.group(1);
          break;
        }
      }
      entryId ??= RegExp(r'playlists/entry/delete/(\d+)')
          .firstMatch(html)
          ?.group(1);
      if (entryId == null) return false;

      final response = await http
          .post(
            Uri.parse('$_baseUrl/playlists/entry/delete/$entryId'),
            headers: {
              'User-Agent': _userAgent,
              'Cookie': cookie,
              'X-Requested-With': 'XMLHttpRequest',
              'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
              'Accept': 'application/json, text/javascript, */*; q=0.01',
              'Referer': editUrl,
            },
            body: 'userkey=${Uri.encodeQueryComponent(userkey)}',
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        debugPrint('[ng] entry/delete -> ${response.statusCode}');
        return false;
      }
      final json = jsonDecode(response.body);
      return json is Map && json['success'] == true;
    } catch (e) {
      debugPrint('[ng] removeFromNgPlaylist failed: $e');
      return false;
    }
  }

  Future<bool> renameNgPlaylist(String playlistId, String title) async {
    final cookie = await NgAuth.getCookie();
    if (cookie == null || cookie.isEmpty) return false;
    final editUrl = '$_baseUrl/playlists/edit/$playlistId';
    try {
      final userkey = _userkeyFrom(await _connectRawAuth(editUrl, cookie));
      if (userkey == null) return false;

      final response = await http
          .post(
            Uri.parse(editUrl),
            headers: {
              'User-Agent': _userAgent,
              'Cookie': cookie,
              'X-Requested-With': 'XMLHttpRequest',
              'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
              'Accept': 'application/json, text/javascript, */*; q=0.01',
              'Referer': editUrl,
            },
            body: 'userkey=${Uri.encodeQueryComponent(userkey)}'
                '&title=${Uri.encodeQueryComponent(title)}',
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        debugPrint('[ng] playlists/edit -> ${response.statusCode}');
        return false;
      }
      final json = jsonDecode(response.body);
      return json is Map && json['success'] == true;
    } catch (e) {
      debugPrint('[ng] renameNgPlaylist failed: $e');
      return false;
    }
  }

  Future<bool> deleteNgPlaylist(String playlistId) async {
    final cookie = await NgAuth.getCookie();
    if (cookie == null || cookie.isEmpty) return false;
    final editUrl = '$_baseUrl/playlists/edit/$playlistId';
    try {
      String? userkey;
      try {
        userkey = _userkeyFrom(await _connectRawAuth(editUrl, cookie));
      } catch (_) {}
      userkey ??= await _fetchUserkey(cookie);
      if (userkey == null) return false;

      final response = await http
          .post(
            Uri.parse('$_baseUrl/playlists/delete/$playlistId'),
            headers: {
              'User-Agent': _userAgent,
              'Cookie': cookie,
              'X-Requested-With': 'XMLHttpRequest',
              'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
              'Accept': 'application/json, text/javascript, */*; q=0.01',
              'Referer': editUrl,
            },
            body: 'userkey=${Uri.encodeQueryComponent(userkey)}',
          )
          .timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        debugPrint('[ng] playlists/delete -> ${response.statusCode}');
        return false;
      }
      final json = jsonDecode(response.body);
      return json is Map && json['url'] != null;
    } catch (e) {
      debugPrint('[ng] deleteNgPlaylist failed: $e');
      return false;
    }
  }


  void _enrichFallback(Track track, String html) {
    try {
      final doc = htmlParser.parse(html);
      track.mp3Url ??= doc
          .querySelector('meta[property="og:audio"]')
          ?.attributes['content'];
    } catch (_) {}
    parseListenDetails(track, html);
  }

  void parseListenDetails(Track track, String html) {
    try {
      final doc = htmlParser.parse(html);
      for (final el in doc.querySelectorAll('script, style, noscript')) {
        el.remove();
      }

      for (final dl in doc.querySelectorAll('dl.sidestats')) {
        String? key;
        for (final el in dl.children) {
          if (el.localName == 'dt') {
            key = el.text.trim().toLowerCase();
            continue;
          }
          if (el.localName != 'dd' || key == null) continue;
          final value = el.text.replaceAll(RegExp(r'\s+'), ' ').trim();
          switch (key) {
            case 'listens':
              track.listens = value;
            case 'faves':
              track.faves = value;
            case 'downloads':
              track.downloads = value;
            case 'votes':
              track.votes = value;
            case 'score':
              final waiting = RegExp(r'Waiting for (\d+) more')
                  .firstMatch(value);
              if (waiting != null) {
                track.votesPending = int.parse(waiting.group(1)!);
                track.score = null;
              } else {
                final m = RegExp(r'([\d.]+)').firstMatch(value);
                if (m != null) track.score = m.group(1);
              }
            case 'uploaded':
              final m =
                  RegExp(r'^([A-Z][a-z]{2,8} \d{1,2}, \d{4})').firstMatch(value);
              track.uploaded = m?.group(1) ?? value;
            case 'genre':
              if (value.isNotEmpty) track.genre = value;
            case 'file info':
              track.fileInfo = value.replaceAll(RegExp(r'\s*\|\s*'), ' | ');
          }
          key = null;
        }
      }

      for (final dl in doc.querySelectorAll('dl.sidestats')) {
        final dt = dl.querySelector('dt');
        if (dt == null || dt.text.trim().toLowerCase() != 'file info') continue;
        final parts = dl
            .querySelectorAll('dd .value')
            .map((e) => e.text.replaceAll(RegExp(r'\s+'), ' ').trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (parts.isNotEmpty) track.fileInfo = parts.join(' | ');
      }

      final tags = <String>{};
      for (final a in doc.querySelectorAll('a[href*="match=tags"]')) {
        final v = Uri.tryParse(a.attributes['href'] ?? '')
            ?.queryParameters['tags'];
        if (v != null && v.isNotEmpty) tags.add(v);
      }
      for (final a in doc.querySelectorAll('a[href*="/audio/browse/tag/"]')) {
        final m = RegExp(r'/audio/browse/tag/([a-z0-9\-]+)')
            .firstMatch(a.attributes['href'] ?? '');
        if (m != null) tags.add(m.group(1)!);
      }
      if (tags.isNotEmpty) {
        track.tags = tags.toList()
          ..sort()
          ..length = tags.length > 12 ? 12 : tags.length;
      }

      final awards = <TrackAward>[];
      for (final li in doc.querySelectorAll('ul.trophies > li')) {
        final label = li.querySelector('strong')?.text.trim() ?? '';
        if (label.isEmpty) continue;
        final kind = (li.classes.isEmpty ? '' : li.classes.first);
        final link = li.querySelector('a');
        final date = link != null
            ? link.text.trim()
            : li.text
                .replaceFirst(label, '')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
        awards.add(TrackAward(kind: kind, label: label, date: date));
      }
      if (awards.isNotEmpty) track.awards = awards;

      final avatar = doc
              .querySelector('.item-icon image')
              ?.attributes['href'] ??
          doc
              .querySelectorAll('img[src*="uimg.ngfiles.com"]')
              .map((e) => e.attributes['src'])
              .firstWhere((s) => s != null && s.isNotEmpty, orElse: () => null);
      if (avatar != null && avatar.isNotEmpty) {
        track.authorIcon = avatar.split('?').first;
      }

      final myVoteM = RegExp(
        'id="votebar-\\d+"\\s+value="(\\d+)"\\s+checked',
      ).firstMatch(html);
      if (myVoteM != null) {
        track.myVote = int.tryParse(myVoteM.group(1)!);
      }

      final comments = doc.querySelector('#author_comments');
      if (comments != null) {
        final text = comments
            .querySelectorAll('p')
            .map((p) => p.text.replaceAll(RegExp(r'\s+'), ' ').trim())
            .where((s) => s.isNotEmpty)
            .join('\n\n');
        final flat = text.isEmpty
            ? comments.text.replaceAll(RegExp(r'\s+'), ' ').trim()
            : text;
        if (flat.isNotEmpty) track.description = flat;
        final raw = comments.innerHtml.trim();
        if (raw.isNotEmpty) track.descriptionHtml = raw;
      }

      final cc = doc.querySelector('#creative_commons .pod-body');
      if (cc != null) {
        final text = cc.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text.isNotEmpty) track.license = text;
      }
    } catch (_) {}
  }

  String _imgSrc(Element? img) {
    if (img == null) return '';
    for (final attr in ['data-smartload-src', 'data-src', 'src']) {
      final v = img.attributes[attr]?.trim() ?? '';
      if (v.isNotEmpty && v.contains('ngfiles.com')) return v;
    }
    return img.attributes['src']?.trim() ?? '';
  }

  List<Track> _parseArtistItems(Document doc, String artist) {
    final result = <Track>[];
    for (final a in doc.querySelectorAll('a.item-audiosubmission')) {
      final href = a.attributes['href'] ?? '';
      final id = href.trimRight().split('/').last;
      if (id.isEmpty) continue;

      final title = (a.attributes['title'] ?? '').trim();
      if (title.isEmpty) continue;

      final iconUrl = _imgSrc(a.querySelector('img'));

      final durationStr = a.attributes['data-audio-duration'] ??
          a.parent?.attributes['data-audio-duration'] ?? '';
      final duration = int.tryParse(durationStr) ?? 0;
      final audioTypeStr = a.attributes['data-audio-type'] ??
          a.parent?.attributes['data-audio-type'] ?? '';
      final audioType = int.tryParse(audioTypeStr) ?? 3;

      result.add(Track(
        id: id,
        title: title,
        artist: artist,
        genre: '',
        iconUrl: iconUrl,
        duration: duration,
        audioType: audioType,
      ));
    }
    return result;
  }

  Future<List<Track>> _parseTracks(String url) async {
    final doc = await _connect(url);
    return _parseItems(doc);
  }

  List<Track> _parseItems(Document doc) {
    final items = doc.querySelectorAll('li[data-hub-id]');
    final result = <Track>[];

    for (final li in items) {
      final id = li.attributes['data-hub-id'] ?? '';
      if (id.isEmpty) continue;

      final playEl = li.querySelector('[data-audio-duration]') ??
          li.querySelector('[data-hub-id]');

      final title = (li.querySelector('.detail-title h4') ??
              li.querySelector('h4.item-title') ??
              li.querySelector('h4') ??
              li.querySelector('.title'))
          ?.text
          .trim();
      if (title == null || title.isEmpty) continue;

      final artist = (li.querySelector('.detail-title strong') ??
              li.querySelector('strong') ??
              li.querySelector('.item-details-main strong') ??
              li.querySelector('.detail-author'))
          ?.text
          .trim() ??
          '';

      final genreEl = li.querySelector('.detail-description') ??
          li.querySelector('.genre') ??
          li.querySelector('.item-details-secondary');
      final genre = genreEl?.text.trim() ?? '';

      final durationStr = playEl?.attributes['data-audio-duration'] ??
          li.attributes['data-audio-duration'] ?? '';
      final duration = int.tryParse(durationStr) ?? 0;

      final audioTypeStr = playEl?.attributes['data-audio-type'] ??
          li.attributes['data-audio-type'] ?? '';
      final audioType = int.tryParse(audioTypeStr) ?? 3;

      final iconUrl = _imgSrc(li.querySelector('img'));

      result.add(Track(
        id: id,
        title: title,
        artist: artist,
        genre: genre,
        iconUrl: iconUrl,
        duration: duration,
        audioType: audioType,
      ));
    }
    return result;
  }

  List<Track> _parseSearchItems(Document doc) {
    final items = doc.querySelectorAll('ul.itemlist li');
    final result = <Track>[];

    for (final li in items) {
      if (li.querySelector('div.audio-wrapper') == null) continue;
      final a = li.querySelector('a.item-audiosubmission');
      if (a == null) continue;

      final href = a.attributes['href'] ?? '';
      final id = href.trimRight().split('/').last;
      if (id.isEmpty) continue;

      final fullTitle = (a.attributes['title'] ?? '').trim();
      if (fullTitle.isEmpty) continue;

      final artist = li.querySelector('.detail-author')?.text.trim() ??
          li.querySelector('strong')?.text.trim() ?? '';

      final actualTitle =
          (fullTitle.contains(' - ') && fullTitle.startsWith(artist))
              ? fullTitle.split(' - ').skip(1).join(' - ').trim()
              : fullTitle;

      final genre = li.querySelector('.detail-description')?.text.trim() ?? '';
      final durationStr = li
          .querySelector('[data-audio-duration]')
          ?.attributes['data-audio-duration'] ?? '';
      final duration = int.tryParse(durationStr) ?? 0;
      final audioTypeStr = li
          .querySelector('[data-audio-type]')
          ?.attributes['data-audio-type'] ?? '';
      final audioType = int.tryParse(audioTypeStr) ?? 3;

      final iconUrl = _imgSrc(li.querySelector('img'));

      result.add(Track(
        id: id,
        title: actualTitle,
        artist: artist,
        genre: genre,
        iconUrl: iconUrl,
        duration: duration,
        audioType: audioType,
      ));
    }
    return result;
  }


  static Map<String, String> _headers({String? cookie, String? referer}) => {
        'User-Agent': _userAgent,
        'Accept':
            'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8',
        'Accept-Language': 'en-US,en;q=0.9',
        'Upgrade-Insecure-Requests': '1',
        'sec-ch-ua':
            '"Chromium";v="124", "Google Chrome";v="124", "Not-A.Brand";v="99"',
        'sec-ch-ua-mobile': '?1',
        'sec-ch-ua-platform': '"Android"',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': referer == null ? 'none' : 'same-origin',
        'Sec-Fetch-User': '?1',
        if (referer != null) 'Referer': referer,
        if (cookie != null && cookie.isNotEmpty) 'Cookie': cookie,
      };

  Future<http.Response> _fetch(String url, {String? cookie}) async {
    var target = Uri.parse(url);
    http.Response? response;

    for (var hop = 0; hop < 5; hop++) {
      final request = http.Request('GET', target)..followRedirects = false;
      request.headers.addAll(_headers(cookie: cookie, referer: _baseUrl));
      response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 20)),
      );

      if (!response.isRedirect) break;
      final location = response.headers['location'];
      if (location == null || location.isEmpty) break;
      target = target.resolve(location);
    }

    final result = response!;
    if (result.statusCode != 200) {
      final h = result.headers;
      debugPrint('[ng] $url -> ${result.statusCode} '
          'server=${h['server']} cf-mitigated=${h['cf-mitigated']} '
          'cf-ray=${h['cf-ray']} len=${result.body.length}');
      final body = result.body;
      debugPrint(
          '[ng] body: ${body.substring(0, body.length < 300 ? body.length : 300)}');
    }
    return result;
  }

  Future<String> _connectRaw(String url) async {
    final response = await _fetch(url);
    if (response.statusCode != 200) {
      throw response.statusCode >= 500
          ? NgSiteDownException(response.statusCode, url)
          : Exception('HTTP ${response.statusCode} for $url');
    }
    return response.body;
  }

  Future<Document> _connect(String url) async {
    final response = await _fetch(url);
    if (response.statusCode != 200) {
      throw response.statusCode >= 500
          ? NgSiteDownException(response.statusCode, url)
          : Exception('HTTP ${response.statusCode} for $url');
    }
    return htmlParser.parse(response.body);
  }

  Future<String> _connectRawAuth(String url, String cookie) async {
    final response = await _fetch(url, cookie: cookie);
    if (response.statusCode != 200) {
      throw response.statusCode >= 500
          ? NgSiteDownException(response.statusCode, url)
          : Exception('HTTP ${response.statusCode} for $url');
    }
    return response.body;
  }
}
