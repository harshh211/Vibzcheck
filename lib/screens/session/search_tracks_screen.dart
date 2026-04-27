import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/track.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/spotify_service.dart';
import '../../widgets/track_tile.dart';

/// SearchTracksScreen lets a session member search Spotify and tap a
/// result to add it to the session's queue. Search is debounced so we
/// don't hit Spotify's rate limit while the user is still typing.
class SearchTracksScreen extends StatefulWidget {
  final String sessionId;
  const SearchTracksScreen({super.key, required this.sessionId});

  @override
  State<SearchTracksScreen> createState() => _SearchTracksScreenState();
}

class _SearchTracksScreenState extends State<SearchTracksScreen> {
  final _searchController = TextEditingController();
  final _spotify = SpotifyService();

  Timer? _debounce;
  List<Track> _results = [];
  bool _isSearching = false;
  String? _error;

  // Tracks we've already added in this search session, keyed by spotifyId.
  // Used to grey out the "added" button so users don't double-add.
  final Set<String> _addedSpotifyIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    // Cancel the previous pending search and schedule a new one.
    // 350ms feels responsive without burning quota on every keystroke.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      _runSearch(value);
    });
  }

  Future<void> _runSearch(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      if (!mounted) return;
      setState(() {
        _results = [];
        _error = null;
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final results = await _spotify.searchTracks(trimmed);
      // The user may have typed more characters while we waited — discard
      // stale results if the query no longer matches.
      if (!mounted || _searchController.text.trim() != trimmed) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Search failed. Check your connection and try again.';
        _isSearching = false;
      });
    }
  }

  Future<void> _addTrack(Track track) async {
    final userId = context.read<AuthProvider>().currentUser?.uid;
    if (userId == null) return;

    final success = await context.read<SessionProvider>().addTrack(
          sessionId: widget.sessionId,
          track: track,
          addedBy: userId,
        );

    if (!mounted) return;

    if (success) {
      setState(() => _addedSpotifyIds.add(track.spotifyId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${track.title}" to the queue'),
          duration: const Duration(seconds: 1),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add track')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add tracks'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search Spotify',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onQueryChanged('');
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_searchController.text.trim().isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Search for a song, artist, or album.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No matches. Try a different search.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final track = _results[index];
        final alreadyAdded = _addedSpotifyIds.contains(track.spotifyId);
        return TrackTile(
          track: track,
          trailing: alreadyAdded
              ? const Icon(Icons.check_circle, color: Colors.green)
              : IconButton(
                  icon: const Icon(Icons.add_circle_outline),
                  tooltip: 'Add to queue',
                  onPressed: () => _addTrack(track),
                ),
        );
      },
    );
  }
}