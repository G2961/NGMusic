class TrackAward {
  final String kind;
  final String label;
  final String date;

  const TrackAward({required this.kind, required this.label, this.date = ''});
}

class Track {
  final String id;
  final String title;
  final String artist;
  String genre;
  String iconUrl;
  final int duration;
  final int audioType;
  String? mp3Url;
  String? score;
  String? votes;

  int? votesPending;

  String? listens;

  String? downloads;
  String? faves;
  String? bpm;

  String? uploaded;

  String? fileInfo;

  List<String> tags = [];

  List<TrackAward> awards = [];

  String? authorIcon;

  String? description;

  String? descriptionHtml;

  int? myVote;

  String? license;

  Track({
    required this.id,
    required this.title,
    required this.artist,
    required this.genre,
    required this.iconUrl,
    required this.duration,
    required this.audioType,
    this.mp3Url,
    this.score,
    this.votes,
    this.votesPending,
    this.listens,
    this.downloads,
    this.faves,
    this.bpm,
  });

  bool get _hasRealIcon => iconUrl.contains('aicon.ngfiles.com');

  String? get _iconFolder {
    final numId = int.tryParse(id);
    return numId == null ? null : '${numId ~/ 1000}';
  }

  String get aIconUrl {
    if (_hasRealIcon) return iconUrl;
    final folder = _iconFolder;
    if (folder == null) return iconUrl;
    return 'https://aicon.ngfiles.com/$folder/${id}_raw.png';
  }

  List<String> get artworkUrls {
    final out = <String>[];
    final folder = _iconFolder;
    if (folder != null) {
      out.add('https://aicon.ngfiles.com/$folder/${id}_raw.png');
      out.add('https://aicon.ngfiles.com/$folder/${id}_raw.jpg');
    }
    if (_hasRealIcon) {
      out.add(iconUrl
          .replaceAll('_medium.', '_full.')
          .replaceAll('_small.', '_full.'));
      out.add(iconUrl);
    } else if (iconUrl.isNotEmpty) {
      out.add(iconUrl);
    }
    return out;
  }

  String get largeIconUrl =>
      artworkUrls.isEmpty ? iconUrl : artworkUrls.first;

  String get audioBaseUrl {
    final numId = int.tryParse(id);
    if (numId == null) return '';
    final folder = (numId ~/ 1000) * 1000;
    return 'https://audio.ngfiles.com/$folder/';
  }
}
