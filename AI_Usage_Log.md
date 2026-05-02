AI Usage Transparency Log — Vibzcheck
Project: Vibzcheck — Collaborative Music App
Course: Mobile App Development
Team: Harshvardhan Kamble, Eshika Julian
Repository: https://github.com/harshh211/Vibzcheck


This log documents all AI tool usage throughout the project sprint (Apr 14 – May 3, 2026),
in accordance with the group project AI usage policy. AI was used as a learning and
debugging assistant — not to generate entire codebases or bypass original development work.


Log Entries

Entry 1
Date: April 14, 2026
Tool: Claude (Anthropic)
What was asked / generated:
Asked Claude to help set up the Flutter project structure with Firebase — specifically how to configure firebase_options.dart using the FlutterFire CLI and how to structure the initial folder layout (models/, services/, providers/, screens/, widgets/).
How it was applied:
Used the suggested folder structure as a starting point. Ran flutterfire configure ourselves and verified the generated firebase_options.dart matched our Firebase project settings.
Reflection:
Learned how FlutterFire CLI generates platform-specific Firebase config and why it's safer than manually copying API keys.

Entry 2
Date: April 16, 2026
Tool: Claude (Anthropic)
What was asked / generated:
Asked for help writing AuthService — specifically the sign-up flow that creates both a Firebase Auth user and a Firestore profile document atomically.
How it was applied:
Reviewed the suggested implementation, understood why updateDisplayName needed to be called separately from createUserWithEmailAndPassword, and integrated it into our auth_service.dart.
Reflection:
Learned that Firebase Auth and Firestore are separate systems — creating an Auth user doesn't automatically create a Firestore document. The two-step write pattern is a common Flutter/Firebase pattern.

Entry 3
Date: April 18, 2026
Tool: Claude (Anthropic)
What was asked / generated:
Asked Claude to explain Firestore security rules and help write rules that scope reads/writes to authenticated users using request.auth.uid.
How it was applied:
Used the explained patterns to write our own firestore.rules file. Tested rules in the Firebase console Rules Playground before deploying.
Reflection:
Understood the difference between allow read and allow write, and why session membership checks (resource.data.memberIds.hasAny([request.auth.uid])) are important for collaborative apps.

Entry 4
Date: April 20, 2026
Tool: Claude (Anthropic)
What was asked / generated:
Asked Claude to review the FirestoreService.voteOnTrack implementation and confirm the atomic transaction logic was correct for preventing race conditions.
How it was applied:
Claude confirmed the pattern was correct and explained why tx.get() inside runTransaction guarantees no other writer modifies the doc between read and write. We kept our implementation unchanged after understanding the logic.
Reflection:
Deepened understanding of Firestore transactions — specifically that Firestore retries the transaction automatically if a concurrent write is detected, which is the core of our race condition prevention.

Entry 5
Date: April 21, 2026
Tool: Claude (Anthropic)
What was asked / generated:
Asked for help integrating the Spotify Web API using the client-credentials flow. Specifically how to cache the access token and refresh it before expiry without concurrent duplicate requests.
How it was applied:
Implemented _getToken() in spotify_service.dart using the suggested caching pattern (store token + expiry, check with 30-second buffer). Wrote the HTTP calls ourselves using the http package.
Reflection:
Learned about the client-credentials OAuth flow and why it's appropriate for server-to-server (or class project) use cases but not suitable for production user-facing apps where the secret would need to stay server-side.

Entry 6
Date: April 23, 2026
Tool: Claude (Anthropic)
What was asked / generated:
Asked Claude to help debug a Flutter analyzer error where Future was being treated as not_a_type in firestore_service.dart. The issue turned out to be a duplicate comment block that broke the method indentation.
How it was applied:
Claude identified the duplicate comment issue and provided the corrected indentation. We verified the fix by running flutter analyze and confirming 0 errors.
Reflection:
Learned to be careful when inserting new methods near existing ones — duplicate doc comments and misaligned indentation can cause subtle parser errors in Dart that look unrelated to the actual problem.

Entry 7
Date: April 25, 2026
Tool: Claude (Anthropic)
What was asked / generated:
Asked for help building the RecommendationEngine — specifically how to design a transparent if/then scoring system using mood tags, vote scores, and audio features that satisfies the project's AI Must-Solve Challenge requirement.
How it was applied:
Reviewed the scoring rules (popularity weight, mood match weight, audio feature similarity, penalty for already-voted tracks) and understood each rule before integrating. Added the _AudioProfile internal class and _computeSessionAudioProfile method after understanding the averaging logic.
Reflection:
Learned the value of transparent, explainable rule-based recommendation systems over black-box ML models — especially for a class project where you need to defend every scoring decision during the demo.

Entry 8
Date: April 27, 2026
Tool: Claude (Anthropic)
What was asked / generated:
Asked Claude to help implement FCM push notifications — specifically the full token lifecycle (request permission, save token to Firestore, listen for token refreshes, send notifications via FCM HTTP v1 API using a service account).
How it was applied:
Implemented messaging_service.dart following the explained pattern. Used googleapis_auth for the OAuth2 service account flow. Tested notification delivery by running the app on two devices simultaneously.
Reflection:
Learned that FCM HTTP v1 API requires OAuth2 bearer tokens (not the legacy server key), and that sending from the client requires shipping the service account JSON — a trade-off we documented in our demo as a known production concern.

Entry 9
Date: April 28, 2026
Tool: Claude (Anthropic)
What was asked / generated:
Asked Claude to help debug a sign-out UX issue where tapping "Sign out" required two taps and showed a loading screen that only dismissed after pressing the Android back button.
How it was applied:
Claude identified that the StreamBuilder wrapping the profile body was causing a rebuild when auth.currentUser became null, and that AuthGate wasn't navigating fast enough. Fixed by adding popUntil in a addPostFrameCallback and adding an isSigningOut guard to prevent double-tap.
Reflection:
Learned about Flutter's widget lifecycle and why StreamBuilder rebuilds can interfere with navigation. addPostFrameCallback is the correct pattern for triggering navigation from inside a build method.

Entry 10
Date: April 29, 2026
Tool: Claude (Anthropic)
What was asked / generated:
Asked Claude to review the full project against the proposal requirements and rubric to identify gaps before final submission.
How it was applied:
Used the audit output to prioritize remaining work: completing the insights screen, settings screen, audio feature badges on track tiles, and submission documents (README, AI log).
Reflection:
Found that doing a structured gap analysis against the rubric before the final sprint is much more effective than building features without checking alignment. Several screens we thought were optional were actually proposal-listed deliverables.

Summary
#DateToolArea1Apr 14ClaudeProject setup, Firebase config2Apr 16ClaudeFirebase Auth + Firestore sign-up flow3Apr 18ClaudeFirestore Security Rules4Apr 20ClaudeAtomic transaction review5Apr 21ClaudeSpotify API client-credentials integration6Apr 23ClaudeDart analyzer bug fix7Apr 25ClaudeRecommendation engine design8Apr 27ClaudeFCM push notifications9Apr 28ClaudeSign-out UX bug fix10Apr 29ClaudeRubric gap analysis
Total AI-assisted sessions: 10
Primary tool: Claude (Anthropic)
Policy compliance: AI was used for learning, debugging, and code review — not to generate entire features without understanding. Every AI suggestion was reviewed, tested, and integrated by a team member.