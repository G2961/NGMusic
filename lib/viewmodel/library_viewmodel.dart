import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/model/playlist.dart';
import '../data/model/track.dart';
import '../data/repository/local_db.dart';
import '../data/repository/ng_repository.dart';
import '../data/repository/ng_auth.dart';

enum FavoriteSaveTarget { local, newgrounds }

enum PlaylistTarget { local, newgrounds }

enum LibrarySection { local, newgrounds, favLocal, favNewgrounds }

class LibraryViewModel extends ChangeNotifier {
  final _db = LocalDb.instance;
  final _repo = NgRepository();

  List<Playlist> playlists = [];
  List<Favorite> favorites = [];
  bool isLoading = false;
  bool isSyncingNg = false;
  bool isLoggedIn = false;

  String? lastError;

  final _favoriteIds = <String>{};

  FavoriteSaveTarget _favTarget = FavoriteSaveTarget.local;
  FavoriteSaveTarget get favTarget => _favTarget;

  Future<bool> favGoesToNg() async =>
      _favTarget == FavoriteSaveTarget.newgrounds && await NgAuth.isLoggedIn();

  final _collapsed = <LibrarySection>{};

  LibraryViewModel() {
    _loadPrefs();
    _init();
  }

  Future<void> _init() async {
    await refresh();
    final username = await NgAuth.getUsername();
    if (username != null && username.isNotEmpty && username != 'unknown') {
      isLoggedIn = true;
      await syncNgPlaylists(username);
    } else {
      isLoggedIn = await NgAuth.isLoggedIn();
      notifyListeners();
    }
    await _reconcileNgFavorites();
  }

  List<Playlist> get localPlaylists =>
      playlists.where((p) => p.ngId == null).toList();

  List<Playlist> get ngPlaylists =>
      playlists.where((p) => p.ngId != null).toList();

  List<Favorite> get localFavorites =>
      favorites.where((f) => !f.isNg).toList();

  List<Favorite> get ngFavorites => favorites.where((f) => f.isNg).toList();


  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    _favTarget = p.getString('fav_save_target') == 'newgrounds'
        ? FavoriteSaveTarget.newgrounds
        : FavoriteSaveTarget.local;
    for (final s in LibrarySection.values) {
      if (p.getBool('section_collapsed_${s.name}') == true) _collapsed.add(s);
    }
    notifyListeners();
  }

  Future<void> setFavTarget(FavoriteSaveTarget t) async {
    _favTarget = t;
    final p = await SharedPreferences.getInstance();
    await p.setString('fav_save_target',
        t == FavoriteSaveTarget.newgrounds ? 'newgrounds' : 'local');
    notifyListeners();
  }

  bool isCollapsed(LibrarySection s) => _collapsed.contains(s);

  Future<void> toggleSection(LibrarySection s) async {
    if (!_collapsed.remove(s)) _collapsed.add(s);
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool('section_collapsed_${s.name}', _collapsed.contains(s));
  }

  void clearError() {
    if (lastError == null) return;
    lastError = null;
    notifyListeners();
  }

  Future<void> refresh() async {
    isLoading = true;
    notifyListeners();
    playlists = await _db.getPlaylists();
    favorites = await _db.getFavorites();
    _favoriteIds
      ..clear()
      ..addAll(favorites.map((f) => f.trackId));
    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshFavorites() async {
    isLoading = true;
    isSyncingNg = true;
    notifyListeners();
    try {
      await refresh();
      final username = await NgAuth.getUsername();
      final logged = username != null &&
          username.isNotEmpty &&
          username != 'unknown' &&
          await NgAuth.isLoggedIn();
      if (logged) {
        isLoggedIn = true;
        await syncNgPlaylists(username);
        await _reconcileNgFavorites();
      }
    } finally {
      isSyncingNg = false;
      notifyListeners();
    }
  }


  bool isFavorite(String trackId) => _favoriteIds.contains(trackId);

  final _favoriteSyncing = <String>{};
  bool isFavoriteSyncing(String trackId) => _favoriteSyncing.contains(trackId);

  Future<bool> toggleFavorite(Track track) async {
    final adding = !_favoriteIds.contains(track.id);

    final useNg = _favTarget == FavoriteSaveTarget.newgrounds &&
        await NgAuth.isLoggedIn();

    if (useNg) {
      _favoriteSyncing.add(track.id);
      lastError = null;
      notifyListeners();
      final confirmed = await _repo.setFavorite(track.id, adding);
      _favoriteSyncing.remove(track.id);
      if (confirmed != adding) {
        lastError = adding
            ? 'Newgrounds не принял добавление в избранное'
            : 'Newgrounds не принял удаление из избранного';
        notifyListeners();
        return false;
      }
    }

    await _db.toggleFavorite(track, isNg: useNg);
    if (adding && useNg) {
      await _db.setFavoriteIsNg(track.id, true);
    }
    if (adding) {
      _favoriteIds.add(track.id);
    } else {
      _favoriteIds.remove(track.id);
    }
    await refresh();
    return true;
  }


  Future<Playlist> createLocalPlaylist(String name, {String? description}) async {
    final p = await _db.createPlaylist(name, description: description);
    await refresh();
    return p;
  }

  Future<Playlist?> createPlaylist(
    String name, {
    PlaylistTarget target = PlaylistTarget.local,
    String? seedTrackId,
  }) async {
    if (target == PlaylistTarget.local) {
      return createLocalPlaylist(name);
    }

    if (!await NgAuth.isLoggedIn()) {
      lastError = 'Войдите в аккаунт Newgrounds, чтобы создавать плейлисты там';
      notifyListeners();
      return null;
    }

    isSyncingNg = true;
    lastError = null;
    notifyListeners();
    final ngId = await _repo.createNgPlaylist(name, seedTrackId: seedTrackId);
    isSyncingNg = false;
    if (ngId == null) {
      lastError = 'Не удалось создать плейлист на Newgrounds';
      notifyListeners();
      return null;
    }
    final p = await _db.createPlaylistWithNgId(name, ngId: ngId);
    await refresh();
    return p;
  }

  Future<bool> renamePlaylist(int id, String name) async {
    final pl = playlists.firstWhere((p) => p.id == id,
        orElse: () => Playlist(name: name, createdAt: 0));
    if (pl.ngId != null) {
      isSyncingNg = true;
      lastError = null;
      notifyListeners();
      final ok = await _repo.renameNgPlaylist(pl.ngId!, name);
      isSyncingNg = false;
      if (!ok) {
        lastError = 'Не удалось переименовать плейлист на Newgrounds';
        notifyListeners();
        return false;
      }
    }
    await _db.renamePlaylist(id, name);
    await refresh();
    return true;
  }

  Future<bool> deletePlaylist(int id) async {
    final pl = playlists.firstWhere((p) => p.id == id,
        orElse: () => const Playlist(name: '', createdAt: 0));
    if (pl.ngId != null) {
      isSyncingNg = true;
      lastError = null;
      notifyListeners();
      final ok = await _repo.deleteNgPlaylist(pl.ngId!);
      isSyncingNg = false;
      if (!ok) {
        lastError = 'Не удалось удалить плейлист на Newgrounds';
        notifyListeners();
        return false;
      }
    }
    await _db.deletePlaylist(id);
    await refresh();
    return true;
  }

  Future<List<PlaylistTrack>> getPlaylistTracks(int playlistId) =>
      _db.getPlaylistTracks(playlistId);

  Future<bool> isTrackInPlaylist(int playlistId, String trackId) =>
      _db.isTrackInPlaylist(playlistId, trackId);

  Future<void> addTrackToLocalPlaylist(int playlistId, Track track) async {
    await _db.addTrackToPlaylist(playlistId, track);
    await refresh();
  }

  Future<bool> addTrackToPlaylist(Playlist pl, Track track) async {
    if (pl.ngId != null) {
      isSyncingNg = true;
      lastError = null;
      notifyListeners();
      final ok = await _repo.addToNgPlaylist(track.id, playlistId: pl.ngId);
      isSyncingNg = false;
      if (!ok) {
        lastError = 'Newgrounds не принял добавление в плейлист';
        notifyListeners();
        return false;
      }
    }
    if (pl.id != null) await _db.addTrackToPlaylist(pl.id!, track);
    await refresh();
    return true;
  }

  Future<Playlist?> createPlaylistWithTrack(
    String name, {
    required PlaylistTarget target,
    required Track track,
  }) async {
    final pl =
        await createPlaylist(name, target: target, seedTrackId: track.id);
    if (pl == null || pl.id == null) return null;
    await _db.addTrackToPlaylist(pl.id!, track);
    await refresh();
    return pl;
  }

  Future<bool> removeTrackFromPlaylist(int playlistId, String trackId) async {
    final pl = playlists.firstWhere((p) => p.id == playlistId,
        orElse: () => const Playlist(name: '', createdAt: 0));
    await _db.removeTrackFromPlaylist(playlistId, trackId);
    if (pl.ngId != null) {
      isSyncingNg = true;
      lastError = null;
      notifyListeners();
      final ok = await _repo.removeFromNgPlaylist(pl.ngId!, trackId);
      isSyncingNg = false;
      if (!ok) {
        lastError = 'Не удалось убрать трек из плейлиста на Newgrounds';
        notifyListeners();
        return false;
      }
    }
    await refresh();
    return true;
  }

  Future<List<PlaylistTrack>> loadPlaylistTracks(
    Playlist playlist, {
    ValueChanged<List<PlaylistTrack>>? onSynced,
  }) async {
    final local = await _db.getPlaylistTracks(playlist.id!);
    if (playlist.ngId == null) return local;

    unawaited(() async {
      List<PlaylistTrack> fresh = local;
      var changed = false;
      try {
        final remote = await _repo.getNgPlaylistTracks(playlist.ngId!);
        final localIds = local.map((t) => t.trackId).toSet();
        final remoteIds = remote.map((t) => t.id).toSet();
        for (final t in remote) {
          if (!localIds.contains(t.id)) {
            await _db.addTrackToPlaylist(playlist.id!, t);
            changed = true;
          }
        }
        for (final t in local) {
          if (!remoteIds.contains(t.trackId)) {
            await _db.removeTrackFromPlaylist(playlist.id!, t.trackId);
            changed = true;
          }
        }
        if (changed) fresh = await _db.getPlaylistTracks(playlist.id!);
      } catch (_) {
        return;
      }
      if (changed) onSynced?.call(fresh);
    }());

    return local;
  }


  Future<void>? _ngSync;

  Future<void> syncNgPlaylists(String username) {
    final running = _ngSync;
    if (running != null) return running;
    final future = _syncNgPlaylists(username);
    _ngSync = future;
    return future.whenComplete(() => _ngSync = null);
  }

  Future<void> _syncNgPlaylists(String username) async {
    isLoggedIn = true;
    isSyncingNg = true;
    notifyListeners();
    try {
      final cloudPlaylists = await _repo.getUserPlaylists(username);
      if (cloudPlaylists.isNotEmpty) {
        final unique = <String, NgCloudPlaylist>{};
        for (final cp in cloudPlaylists) {
          unique.putIfAbsent(cp.id, () => cp);
        }
        final stored = await _db.getPlaylists();
        final mirrors = stored.where((p) => p.ngId != null);
        for (final p in mirrors) {
          if (!unique.containsKey(p.ngId)) {
            await _db.deletePlaylist(p.id!);
          }
        }
        final known = {for (final p in mirrors) p.ngId!: p};
        for (final cp in unique.values) {
          final existing = known[cp.id];
          if (existing == null) {
            await _db.createPlaylistWithNgId(cp.name, ngId: cp.id);
          } else if (existing.name != cp.name) {
            await _db.renamePlaylist(existing.id!, cp.name);
          }
        }
      }
    } catch (_) {}
    isSyncingNg = false;
    await refresh();
  }

  Future<void> clearNgPlaylists() async {
    isLoggedIn = false;
    final mirrors = playlists.where((p) => p.ngId != null).toList();
    for (final p in mirrors) {
      await _db.deletePlaylist(p.id!);
    }
    await refresh();
  }


  static const _reconcileFlag = 'fav_ng_reconciled_v3';

  static const _reconcileLimit = 30;

  Future<void> _reconcileNgFavorites() async {
    final p = await SharedPreferences.getInstance();
    if (p.getBool(_reconcileFlag) == true) return;
    if (!await NgAuth.isLoggedIn()) return;

    final stale = favorites.where((f) => !f.isNg).take(_reconcileLimit).toList();
    if (stale.isEmpty) {
      await p.setBool(_reconcileFlag, true);
      return;
    }

    var changed = false;
    for (final f in stale) {
      final onNg = await _repo.getFavoriteStatus(f.trackId);
      if (onNg == null) return;
      if (onNg) {
        await _db.setFavoriteIsNg(f.trackId, true);
        changed = true;
      }
    }
    await p.setBool(_reconcileFlag, true);
    if (changed) await refresh();
  }
}
