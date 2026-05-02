# Vibzcheck 🎵

**Collaborative Music App** — Flutter & Firebase  
Georgia State University | Mobile App Development | Spring 2026

> Vibzcheck transforms music into a shared, dynamic experience. Everyone in a session can add tracks to a shared queue, vote on what plays next, tag songs with moods, and chat in real time — the digital equivalent of passing around the aux cable.

---

## Features

- **Firebase Authentication** — Email/password sign-up and sign-in
- **Real-Time Queue** — Collaborative track queue powered by Firestore live listeners
- **Democratic Voting** — Upvote/downvote tracks with atomic Firestore transactions (race condition safe)
- **Spotify Integration** — Search Spotify and add any track to the session queue
- **Mood Tagging** — Tag tracks with moods (hype, chill, party, etc.) to shape the vibe
- **Recommendation Engine** — Transparent if/then scoring suggests the next 3 tracks based on votes, mood tags, and audio features
- **Real-Time Chat** — Message other session members live
- **FCM Push Notifications** — Get notified when someone adds a track to your session
- **Firebase Storage** — User avatar upload and management
- **Insights** — View your listening stats, top artists, top moods, and audio profile
- **Settings** — Customize recommendation weights and notification preferences

---

## Tech Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) |
| Auth | Firebase Authentication |
| Database | Cloud Firestore |
| Storage | Firebase Storage |
| Notifications | Firebase Cloud Messaging (FCM) |
| Music API | Spotify Web API (client-credentials flow) |
| State Management | Provider |

---

## Prerequisites

- Flutter SDK `>=3.0.0`
- Dart SDK `>=3.0.0`
- Firebase project (with Auth, Firestore, Storage, FCM enabled)
- Spotify Developer account with a registered app

---

## Setup

### 1. Clone the repository

```bash
git clone [YOUR_GITHUB_REPO_URL]
cd vibzcheck
```

### 2. Install dependencies

```bash
flutter pub get
```

### 3. Configure Firebase

This project uses FlutterFire CLI. The `firebase_options.dart` file is already generated for this project. If you need to reconfigure for your own Firebase project:

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

### 4. Set up Spotify credentials

Create a `.env` file in the project root:

```
SPOTIFY_CLIENT_ID=your_spotify_client_id
SPOTIFY_CLIENT_SECRET=your_spotify_client_secret
```

Get your credentials from the [Spotify Developer Dashboard](https://developer.spotify.com/dashboard).

> ⚠️ Never commit your `.env` file. It is already listed in `.gitignore`.

### 5. Set up FCM service account

Place your Firebase service account JSON file at:

```
assets/service_account.json
```

Download it from: Firebase Console → Project Settings → Service Accounts → Generate new private key.

> ⚠️ Never commit your service account JSON. It is already listed in `.gitignore`.

### 6. Run the app

```bash
flutter run
```

---

## Firestore Data Model

```
/users/{userId}
  displayName: string
  email: string
  avatarUrl: string?
  fcmToken: string?
  createdAt: timestamp
  preferences: {
    notificationsEnabled: bool
    popularityWeight: int
    moodWeight: int
    audioFeatureWeight: int
  }

/sessions/{sessionId}
  name: string
  hostId: string
  joinCode: string        # 6-character alphanumeric
  memberIds: string[]
  isActive: bool
  createdAt: timestamp

  /tracks/{trackId}
    spotifyId: string
    title: string
    artist: string
    albumArtUrl: string
    previewUrl: string?
    addedBy: string        # userId
    addedAt: timestamp
    voteScore: int         # upvoters.length - downvoters.length
    upvoters: string[]
    downvoters: string[]
    moodTags: string[]
    tempo: double?
    energy: double?
    danceability: double?

  /messages/{messageId}
    senderId: string
    text: string
    sentAt: timestamp
```

---

## Architecture

```
lib/
├── main.dart                  # App entry point, AuthGate
├── firebase_options.dart      # FlutterFire generated config
├── models/                    # Data classes (Track, Session, AppUser, Message, MoodTag)
    ├── app_user.dart
    ├── message.dart
    ├── mood_tag.dart
    ├── session.dart
    └── track.dart                  
├── services/                  # Firebase + Spotify service layer
│   ├── auth_service.dart
│   ├── firestore_service.dart
│   ├── spotify_service.dart
│   ├── storage_service.dart
│   ├── messaging_service.dart
│   ├── preferences_service.dart
│   ├── insights_service.dart
│   └── recommendation_engine.dart
├── providers/                 # ChangeNotifier state management
│   ├── auth_provider.dart
│   └── session_provider.dart
├── screens/                   # UI screens
│   ├── auth/
│   │   ├── sign_in_screen.dart
│   │   └── sign_up_screen.dart
│   ├── home/
│   │   ├── home_screen.dart
│   │   ├── create_session_screen.dart
│   │   └── join_session_sheet.dart
│   ├── session/
│   │   ├── session_screen.dart
│   │   ├── chat_screen.dart
│   │   └── search_tracks_screen.dart
│   ├── profile/
│   │   ├── profile_screen.dart
│   │   └── settings_screen.dart
│   └── insights/
│       └── insights_screen.dart
└── widgets/                   # Reusable widgets
    ├── track_tile.dart
    ├── vote_buttons.dart
    └── mood_tag_chip.dart
```

---

## Key Implementation Notes

### Atomic Voting (Race Condition Prevention)
`FirestoreService.voteOnTrack` uses `FirebaseFirestore.runTransaction` to guarantee that concurrent votes from multiple users never lose updates. The transaction reads the current voter arrays, recomputes them, and writes atomically — Firestore retries automatically on conflict.

### Recommendation Engine
`RecommendationEngine.rank` uses transparent if/then scoring rules — no black box. Rules: popularity (vote score × weight), mood tag overlap with session mood, audio feature similarity to session audio profile, penalties for already-voted tracks. Users can tune weights in Settings.

### Spotify API Trade-off
Per the proposal, Spotify integration was planned via Firebase Cloud Functions to keep credentials server-side. For this sprint we implemented client-side via `.env` to meet the 12-day deadline. This trade-off is documented in `spotify_service.dart` and will be defended during the demo.

### FCM Architecture Trade-off
FCM sends are made directly from the client using a service account JSON for the OAuth2 token. In production this would live in a Cloud Function. Documented as a known trade-off.

---

## Building the APK

```bash
flutter build apk --release
```

Output: `build/app/outputs/flutter-apk/app-release.apk`

---

## Team

| Member | Role |
|--------|------|
| [Harshvardhan Kamble] | UI/Frontend Lead |
| [Eshika Julian] | Backend/Firebase Lead |


---

## Submission

- **GitHub Repository:** https://github.com/harshh211/Vibzcheck
- **Demo Video:** [YOUR_YOUTUBE_OR_DRIVE_LINK]
- **Final Delivery:** May 3, 2026

---

*Flutter & Firebase Final Project | Georgia State University | Spring 2026*
