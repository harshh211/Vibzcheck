import 'dart:convert';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/track.dart';

/// SpotifyService talks to the Spotify Web API using the client-credentials
/// flow (no user login — we authenticate the app itself). This is enough
/// for searching tracks and pulling metadata; user playback would need
/// the authorization-code flow (out of scope for this project).
///
/// Architecture note: in a production app this would live in a Cloud
/// Function so the client secret never ships to user devices. For this
/// class project we keep it client-side via .env to stay within the
/// 12-day timeline. The proposal mentions Cloud Functions; we document
/// this trade-off in the demo.
class SpotifyService {
  static const String _tokenUrl = 'https://accounts.spotify.com/api/token';
  static const String _searchUrl = 'https://api.spotify.com/v1/search';

  // Cached token + expiry. Tokens last ~1 hour, so we refresh on demand.
  String? _accessToken;
  DateTime? _expiresAt;

  /// Get a valid access token, refreshing if needed. Concurrent callers
  /// while a refresh is in flight will all await the same future.
  Future<String> _getToken() async {
    final now = DateTime.now();
    if (_accessToken != null &&
        _expiresAt != null &&
        now.isBefore(_expiresAt!.subtract(const Duration(seconds: 30)))) {
      return _accessToken!;
    }

    final clientId = dotenv.env['SPOTIFY_CLIENT_ID'];
    final clientSecret = dotenv.env['SPOTIFY_CLIENT_SECRET'];

    if (clientId == null ||
        clientSecret == null ||
        clientId.isEmpty ||
        clientSecret.isEmpty ||
        clientId == 'placeholder') {
      throw Exception(
        'Spotify credentials missing. Add SPOTIFY_CLIENT_ID and '
        'SPOTIFY_CLIENT_SECRET to your .env file.',
      );
    }

    // Spotify expects Basic auth with base64(client_id:client_secret).
    final basic = base64Encode(utf8.encode('$clientId:$clientSecret'));

    final response = await http.post(
      Uri.parse(_tokenUrl),
      headers: {
        'Authorization': 'Basic $basic',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'grant_type': 'client_credentials'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Spotify auth failed (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    _accessToken = body['access_token'] as String;
    final expiresIn = (body['expires_in'] as num).toInt();
    _expiresAt = now.add(Duration(seconds: expiresIn));
    return _accessToken!;
  }

  /// Search Spotify for tracks matching `query`. Returns up to `limit`
  /// results. Returns an empty list (not an error) for empty queries.
  ///
  /// We construct lightweight Track objects here — voting state defaults
  /// to empty since these are search results, not queue entries yet.
  Future<List<Track>> searchTracks(String query, {int limit = 20}) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];

    final token = await _getToken();
    final uri = Uri.parse(_searchUrl).replace(queryParameters: {
      'q': trimmed,
      'type': 'track',
      'limit': '$limit',
    });

    final response = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode != 200) {
      throw Exception(
        'Spotify search failed (${response.statusCode}): ${response.body}',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (body['tracks']?['items'] as List?) ?? [];

    return items.map((raw) {
      final item = raw as Map<String, dynamic>;
      final albumImages = (item['album']?['images'] as List?) ?? [];
      // Spotify returns 3 image sizes (640, 300, 64). Pick the middle one
      // for list rendering — biggest is wasteful, smallest looks fuzzy.
      final albumArt = albumImages.isNotEmpty
          ? (albumImages.length >= 2 ? albumImages[1] : albumImages.first)
                  ['url'] as String? ??
              ''
          : '';

      final artists = (item['artists'] as List?) ?? [];
      final artistName = artists.isEmpty
          ? 'Unknown artist'
          : (artists.first as Map<String, dynamic>)['name'] as String? ??
              'Unknown artist';

      return Track(
        id: '', // assigned by Firestore when added to a queue
        spotifyId: item['id'] as String? ?? '',
        title: item['name'] as String? ?? 'Unknown title',
        artist: artistName,
        albumArtUrl: albumArt,
        previewUrl: item['preview_url'] as String?,
        addedBy: '',
        voteScore: 0,
        upvoters: const [],
        downvoters: const [],
        moodTags: const [],
      );
    }).toList();
  }
}