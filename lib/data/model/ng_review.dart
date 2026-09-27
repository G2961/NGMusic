class NgReview {
  final String id;
  final String author;
  final String authorSlug;
  final String avatarUrl;
  final String date;
  final double score;
  final String body;

  final String flagUrl;

  final NgReviewResponse? response;

  const NgReview({
    required this.id,
    required this.author,
    required this.authorSlug,
    required this.avatarUrl,
    required this.date,
    this.score = 0,
    required this.body,
    this.flagUrl = '',
    this.response,
  });

  bool get hasScore => score > 0;
}

class NgReviewResponse {
  final String author;
  final String authorSlug;
  final String avatarUrl;
  final String body;

  const NgReviewResponse({
    required this.author,
    this.authorSlug = '',
    this.avatarUrl = '',
    required this.body,
  });
}

class ReviewsPage {
  final List<NgReview> items;
  final int page;
  final int pages;

  const ReviewsPage({required this.items, this.page = 1, this.pages = 1});
}

class VoteResult {
  final double? score;
  final int? votes;
  final bool waiting;

  final int? pendingVotes;

  const VoteResult(
      {this.score, this.votes, this.waiting = false, this.pendingVotes});
}
