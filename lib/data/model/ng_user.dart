class NgUser {
  final String username;
  final String profileUrl;
  final String? avatarUrl;
  final String? age;
  final String? gender;
  final String? country;
  final String? joinDate;
  final String? level;
  final String? exp;
  final String? fans;
  final String? audioCount;
  final bool? isFollowing;

  const NgUser({
    required this.username,
    required this.profileUrl,
    this.avatarUrl,
    this.age,
    this.gender,
    this.country,
    this.joinDate,
    this.level,
    this.exp,
    this.fans,
    this.audioCount,
    this.isFollowing,
  });
}
