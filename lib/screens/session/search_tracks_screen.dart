import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/track.dart';
import '../../providers/auth_provider.dart';
import '../../providers/session_provider.dart';
import '../../services/spotify_service.dart';
import '../../widgets/track_tile.dart';
import '../../services/firestore_service.dart';
import '../../services/messaging_service.dart';

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

  final Set<String> _addedSpotifyIds = {};

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onQueryChanged(String value) {
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
    final user = context.read<AuthProvider>().currentUser;
    if (user == null) return;

    final success = await context.read<SessionProvider>().addTrack(
          sessionId: widget.sessionId,
          track: track,
          addedBy: user.uid,
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

      _notifyMembers(track, user.displayName ?? 'Someone');
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not add track')),
      );
    }
  }

  Future<void> _notifyMembers(Track track, String adderName) async {
    final excludeUid = context.read<AuthProvider>().currentUser?.uid;

    try {
      final memberIds =
          await FirestoreService().getSessionMemberIds(widget.sessionId);

      await MessagingService().sendToUsers(
        userIds: memberIds,
        excludeUid: excludeUid,
        title: 'New track in your session',
        body: '$adderName added "${track.title}" by ${track.artist}',
        data: {'sessionId': widget.sessionId, 'type': 'track_added'},
      );
    } catch (_) {
      // Push notifications are best-effort.
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Tracks'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color.fromARGB(255, 98, 13, 105).withOpacity(0.08),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.library_music,
                    size: 42,
                    color: Color.fromARGB(255, 98, 13, 105),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Find the next vibe',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Search Spotify and add tracks to your session queue.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Search songs, artists, or albums',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _onQueryChanged('');
                          setState(() {});
                        },
                      ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
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
      return _SearchMessage(
        icon: Icons.error_outline,
        title: 'Could not search',
        message: _error!,
      );
    }

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_searchController.text.trim().isEmpty) {
      return const _SearchMessage(
        icon: Icons.search,
        title: 'Start by searching Spotify',
        message: 'Type a song, artist, or album to find tracks.',
      );
    }

    if (_results.isEmpty) {
      return const _SearchMessage(
        icon: Icons.music_off,
        title: 'No matches found',
        message: 'Try searching with a different song or artist name.',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final track = _results[index];
        final alreadyAdded = _addedSpotifyIds.contains(track.spotifyId);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: TrackTile(
            track: track,
            trailing: alreadyAdded
                ? const Icon(Icons.check_circle, color: Colors.green)
                : IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add to queue',
                    onPressed: () => _addTrack(track),
                  ),
          ),
        );
      },
    );
  }
}

class _SearchMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;

  const _SearchMessage({
    required this.icon,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey.shade600,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}