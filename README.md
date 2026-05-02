# 🎧 VibzCheck

VibzCheck is a real-time collaborative music app where users can create or join sessions, search songs using Spotify, and vote on what plays next.

## 🚀 Features
- User authentication (Firebase Auth)
- Create/join sessions
- Spotify song search
- Shared queue with voting
- Real-time updates (Firestore)
- In-session chat

## 🛠 Tech Stack
- Flutter (Dart)
- Firebase (Auth, Firestore, FCM)
- Spotify API

## ⚙️ How It Works
Users join a session → search songs → add to queue → vote → songs reorder based on votes → updates happen in real time.

## ⚙️ Setup
```bash
git clone https://github.com/harshh211/Vibzcheck.git
cd Vibzcheck
flutter pub get
