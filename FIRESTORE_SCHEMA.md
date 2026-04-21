# Vibzcheck — Firestore Data Model

## Collections overview

```
users/{userId}                                        ← top-level
  ├─ displayName: string
  ├─ email: string
  ├─ avatarUrl: string?                               ← Firebase Storage URL
  ├─ fcmToken: string?                                ← for push notifications
  └─ createdAt: timestamp

sessions/{sessionId}                                  ← top-level (a "room")
  ├─ name: string                                     ← e.g. "Friday Night Vibes"
  ├─ hostId: string                                   ← user UID of creator
  ├─ joinCode: string                                 ← 6-char code to join
  ├─ memberIds: string[]                              ← array of user UIDs (for queries)
  ├─ createdAt: timestamp
  ├─ isActive: boolean
  │
  ├─ tracks/{trackId}                                 ← subcollection (queue)
  │    ├─ spotifyId: string
  │    ├─ title: string
  │    ├─ artist: string
  │    ├─ albumArtUrl: string
  │    ├─ previewUrl: string?
  │    ├─ addedBy: string                             ← user UID
  │    ├─ addedAt: timestamp
  │    ├─ voteScore: integer                          ← net score (↑ minus ↓)
  │    ├─ upvoters: string[]                          ← UIDs (for UI state)
  │    ├─ downvoters: string[]                        ← UIDs
  │    └─ moodTags: string[]                          ← ["chill", "party"]
  │
  └─ messages/{messageId}                             ← subcollection (chat)
       ├─ senderId: string
       ├─ text: string
       └─ sentAt: timestamp
```

## Design decisions (ready for Q&A)

**Why subcollections for tracks and messages (not top-level)?**
Tracks and messages only make sense within a session — there's no query like "show me all tracks across all sessions." Subcollections scope the data to its parent and keep security rules simple: "if you're in the session, you can read its tracks." Top-level collections would force every query to include a `where('sessionId', '==', X)` clause and require composite indexes.

**Why `memberIds` as an array on the session doc?**
Flutter's home screen needs "show my sessions." Firestore `array-contains` queries on `memberIds` answer this in one read, versus maintaining a separate `userSessions` collection that would need two writes per join.

**Why `voteScore` denormalized on each track?**
Sorting the queue by popularity means `orderBy('voteScore', descending: true)`. Computing this from vote documents on every read would be expensive. We maintain it through a Firestore **transaction** (see below) whenever someone votes — that guarantees atomicity.

**Why `upvoters` / `downvoters` arrays instead of a votes subcollection?**
Two reasons: (1) the UI needs to know "did I already upvote this?" which is a single-field read, not a subcollection query; (2) the atomic vote transaction updates these arrays + `voteScore` in one shot. The trade-off is these arrays grow with participants — fine for small groups (our use case), would need rethinking at 10k+ voters per track.

## Composite index

The track list query is:
```dart
FirebaseFirestore.instance
  .collection('sessions').doc(sessionId)
  .collection('tracks')
  .orderBy('voteScore', descending: true)
  .orderBy('addedAt', descending: false)        ← tiebreaker: older tracks first
```

This requires a **composite index** on `(voteScore desc, addedAt asc)` — Firestore prompts you to create it on first run.

## Security rules strategy (summary, full file in firestore.rules)

- Anyone signed in can create a session (they become the host).
- Only session members (`memberIds` contains `request.auth.uid`) can read session data and its subcollections.
- Only the track's `addedBy` or the host can delete a track.
- Votes (the transaction) must verify the voter is a session member.
- Chat messages must have `senderId == request.auth.uid`.
