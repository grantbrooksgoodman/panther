# Panther Android Port — Feasibility Assessment & Phased Plan

**Status:** Proposed
**Scope:** MVP with ~80% visual and feature parity with the iOS app, backed by the same Firebase project with strict wire-format parity.

---

## 1. Executive Summary

**Verdict: feasible, with no hard blockers.** Every load-bearing technology in the iOS stack has a first-class Android equivalent, and — unusually for a port — the app's architecture works in Android's favor: the homegrown reducer architecture (AppSubsystem) maps almost mechanically onto Kotlin coroutines + `StateFlow`, and the Firebase iOS SDK surface used by Networking (Auth, Realtime Database, Storage, App Check) exists near-1:1 in the Firebase Android SDK.

**The lift is large but front-loadable.** The iOS surface is ~122K lines of Swift across six repos (Panther ~69K; AppSubsystem ~28K; Networking ~16K; AlertKit ~4K; Translator ~4K; ComponentKit ~1.4K). An Android MVP does not need all of it. With the feature cuts in §7, the port is realistically **30–45K lines of Kotlin**, of which roughly a third is foundation (architecture kernel + backend layer) that unblocks everything else.

**The two big rocks:**

1. **The chat screen.** iOS chat is built on MessageKit + InputBarAccessoryView (UIKit), wrapped in ~30K lines of user-content code including 24 vendored contextual-menu files. None of this ports. The Android chat UI must be **rebuilt natively in Jetpack Compose** against the same reducer contract — a rewrite, not a translation. This is the single largest work item.
2. **The translation stack.** Translator drives Google/DeepL/Reverso/Lara through hidden `WKWebView`s evaluating JavaScript. Android `WebView.evaluateJavascript` supports the same technique, but the port needs real device testing since it depends on each platform's web page structure behaving identically in Chromium.

**The biggest *risk* is not effort — it's silent schema drift.** Wire-format invariants live in code, not docs: a custom timestamp format (`yyyy-MM-dd HH:mm:ss zzz`, POSIX, UTC), SHA-256 identity hashes computed over JSON-encoded string arrays (`EncodedHashable`), macro-generated serialization (`@Serializable`, `@RemotelyUpdatable`), and conventions like "bang-qualified empty" nil handling. §6 enumerates these traps; Phase 1 produces a schema document and shared golden fixtures so both platforms encode/decode against the same bytes.

**Rough calendar:** with Claude Code doing the implementation and you reviewing/testing, expect each phase to take a handful of focused sessions; the full MVP is plausibly an **8–12 week part-time effort**, with a usable Android↔iOS text conversation (Phase 7) reachable around the midpoint.

---

## 2. What the iOS App Is Made Of

| Repo | Lines (Swift) | Files | Role |
|---|---|---|---|
| `panther` | ~69,400 | 474 | App: onboarding, conversations, chat, settings, session sync, app-level schema |
| `app-subsystem` | ~27,700 | 229 | Architecture kernel: Reducer/Effect/ViewModel, DI, SharedState/Events, theming, localization, logging, dev mode |
| `networking` | ~15,900 | 110 | Firebase layer: Auth (anonymous + phone), RTDB (`DatabaseDelegate`), Storage, App Check, hosted translation, Gemini, serialization macros |
| `alert-kit` | ~3,900 | 34 | Translation-aware alerts on `UIAlertController` |
| `translator` | ~3,700 | 31 | Web-based translation via hidden `WKWebView` JS evaluation, with platform fallback + caching |
| `component-kit` | ~1,400 | 16 | Styled text/button/symbol components, font system |

Panther module breakdown (approx.): Content/User (chat, conversations, settings) 29.9K · Common 11K · app-level Networking module (schema serializables + services) 11.8K · Session (store, sync, outbox) 5.7K · Onboarding 3.8K · Content/Shared 2.4K.

**Third-party dependencies:** MessageKit, InputBarAccessoryView (chat UI — will not port), PhoneNumberKit (→ Google's libphonenumber, which is Android-native), firebase-ios-sdk (→ Firebase Android SDK), swift-syntax (macros — replaced by hand-written serializers for MVP).

**Backend shape:** one Firebase project, three logical environments (`development` / `staging` / `production`). Top-level RTDB paths (from `Sources/Bundle/NetworkPaths.swift`): `audioMessageInputs`, `audioTranslations`, `breadcrumbs`, `conversations`, `deletedUsers`, `invalidatedCaches`, `media`, `messages`, `reportedUsers`, `shared`, `translations`, `users`. Messages carry their translations inline; translation happens **client-side** (archive lookup → live web translation → optional Gemini AI enhancement) — so the Android app must ship the translation stack to participate correctly.

---

## 3. Technology Mapping

| iOS | Android | Fit |
|---|---|---|
| SwiftUI screens | Jetpack Compose | Excellent — near-mechanical for Panther's SwiftUI views |
| AppSubsystem `Reducer`/`Effect`/`ViewModel` | Kotlin port: sealed `Action`, data-class `State`, `StateFlow`-backed ViewModel, coroutine effects | Excellent — this is MVI, which is idiomatic Android |
| `@Dependency` / `DependencyValues` | Kotlin port of the same registry (keep names); avoid Hilt/Koin for parity | Good |
| `SharedState` / `SharedEvents` streams | `MutableStateFlow` / `MutableSharedFlow` registry | Excellent |
| Firebase iOS (Auth/RTDB/Storage/AppCheck) | Firebase Android SDK (Play Integrity for App Check) | Near 1:1 API |
| Firebase phone auth (APNs silent push) | Firebase phone auth (Play Integrity / SafetyNet, SHA fingerprints) | 1:1 behavior, different setup |
| MessageKit chat UI (UIKit) | **Rebuild** in Compose (`LazyColumn`, custom bubbles, input bar) | Rewrite |
| PhoneNumberKit | libphonenumber-android | Better on Android |
| `WKWebView` + `evaluateJavaScript` (Translator) | `WebView` + `evaluateJavascript` | Good, needs device validation |
| `UIAlertController` (AlertKit) | Compose `AlertDialog` / `ModalBottomSheet` wrappers with the same translation-aware API | Good |
| Swift macros (`@Serializable`, `@RemotelyUpdatable`) | Hand-written encode/decode + update builders (KSP codegen later if desired) | Manual, well-bounded |
| `CryptoKit` SHA-256 (`EncodedHashable`) | `java.security.MessageDigest` | 1:1, **JSON byte parity required** (§6) |
| `.lproj` `Localizable.strings` + `LocalizedStrings.plist` | `strings.xml` per locale (scripted conversion) + ported runtime lookup | Mechanical |
| San Francisco fonts | **Cannot ship** (Apple license). Use Inter (closest metrics) or Roboto | See §6 |
| NotificationExtension (APNs) | FCM `FirebaseMessagingService` | Standard; pipeline needs investigation (§5) |
| Camera/photo pickers, `AVAudioRecorder` | CameraX / Photo Picker, `MediaRecorder` | Standard (post-MVP for audio) |
| `Panther.xcodeproj` + SwiftPM | Single Gradle project, multi-module | — |
| SwiftLint/SwiftFormat | ktlint + detekt (custom rules per style guide) | Good |

---

## 4. Should the Dependencies Be Ported First?

**Yes — but as Gradle modules inside one new Android repo, not as separate library repos.**

Port order: **AppSubsystem kernel → Networking core → ComponentKit/AlertKit equivalents → Translator**, then the app target. Reasons:

1. **Everything in Panther is written against these abstractions.** Every reducer declares `@Dependency` properties; every screen is a `Reducer` + `ViewModel` pair; every backend call goes through `DatabaseDelegate`/`hostedTranslation`. Porting a screen before the kernel exists means inventing throwaway scaffolding and porting the screen twice.
2. **Keeping the same type names and API shapes makes the port mechanical.** If Kotlin has `Reducer`, `Effect`, `Dependency`, `SharedEvent`, `DatabaseDelegate` with the same semantics, a Claude Code instance can translate `SignInPageReducer.swift` almost line-by-line — and the prose behavior contracts in the iOS doc comments remain directly verifiable against the Kotlin code.
3. **But separate repos are premature.** Publishing Android libraries (Maven coordinates, versioning, release flow) is pure overhead before the APIs stabilize. Use one repo (e.g. `panther-android`) with modules mirroring the package boundaries — `:subsystem`, `:networking`, `:designsystem` (ComponentKit + AlertKit), `:translator`, `:app` — so extraction into standalone libraries later is cheap if you ever build a second Android app.

**What to skip or defer from the packages:** AppSubsystem's UIKit-specific views/modifiers and most of Developer Mode (keep a minimal debug menu); Networking's Health module and Gemini module (defer — AI-enhanced translations are a post-MVP toggle); AlertKit's attributed-string customization surface; Translator's DeepL/Lara/Reverso fallbacks in the first pass (start with Google, add fallbacks once the WebView harness is proven).

---

## 5. Documentation Sufficiency Assessment

**Verdict: sufficient for a careful Claude Code port — provided the iOS repos are checked out side-by-side and Phase 1's parity artifacts are produced first.**

**Strengths (unusually good):**

- Package READMEs are thorough and current: AppSubsystem (1,081 lines, full architecture reference with reducer/effect/DI/observation walkthroughs), Networking (1,016 lines, module-by-module), AlertKit (459), ComponentKit (287), Translator (245).
- Code-level documentation is exceptional. Reducers carry **prose behavior contracts** (e.g. `SignInPageReducer` documents its entire page lifecycle, button-enabling rules, and failure handling in the header comment). Protocols like `DatabaseDelegate` and `EncodedHashable` document semantics, not just signatures. A porting agent can implement against these contracts and self-check.

**Gaps (each is addressed in the plan):**

1. **Panther itself has no README or architecture document.** Module layout, navigation flow, and session lifecycle must be inferred from code. *(Mitigation: Phase 1 produces `ARCHITECTURE.md` as a port byproduct.)*
2. **No RTDB schema document.** The schema exists only implicitly in `*+Serializable.swift` files plus macro-generated code. Field renames on the wire (e.g. `conversationIDs` encodes as `"openConversations"`), map-vs-array encodings, and nil conventions are invisible unless you read every serializer. *(Mitigation: Phase 1 produces `SCHEMA.md` + golden JSON fixtures — the single highest-leverage de-risking artifact.)*
3. **Macro-generated code must be mentally expanded.** `@Serializable`/`@RemotelyUpdatable`/`@Updatable` generate the actual encode/decode/update logic; the macro implementation (~1.1K lines in `networking/Sources/Macros`) is readable but a porting agent must be explicitly directed to it.
4. **The push notification pipeline is undocumented.** How pushes are produced (Cloud Functions? direct?), what the NotificationExtension does with payloads, and what `badgeNumber`/`pushTokens` semantics are — this needs a short investigation before Phase 8.
5. **Firebase project configuration is (correctly) not in the repo** (`GoogleService-Info.plist` is gitignored). The Android setup (registering Android apps, SHA fingerprints, Play Integrity, `google-services.json` per environment) is user-owned work in Phase 0 and needs your Firebase console access.

**Risk framing:** without the Phase 1 artifacts, a port would *work* but could drift subtly (a date format here, a hash factor there) in ways that corrupt shared data or create records iOS can't read. With them, drift becomes a test failure instead of a production incident.

---

## 6. Wire-Format & Parity Traps

These are the specific places an Android implementation can silently diverge. Each becomes a fixture-backed test in Phase 1–2.

1. **Timestamp format.** All serialized dates use `DateFormatter` with `yyyy-MM-dd HH:mm:ss zzz`, `en_US_POSIX`, UTC (`TimestampDateFormatterDependency`). Kotlin must reproduce this exactly — including the `zzz` rendering (`GMT` vs `UTC` token output must be verified against real iOS-written values).
2. **`EncodedHashable`.** Identity hashes = SHA-256 over the **JSON encoding of a `[String]`** of hash factors, lowercase hex, order-sensitive. Kotlin's JSON encoder must match Swift's `JSONEncoder` byte-for-byte for string arrays (escaping rules, no whitespace). Conversation IDs are `(key, hash)` pairs — a wrong hash breaks conversation identity across platforms.
3. **Macro-generated serialization.** Wire keys sometimes differ from property names (`conversationIDs` → `"openConversations"`). Sets encode as `{value: true}` maps (`blockedUserIDs`, `pushTokens`); conversation IDs as `{key: hash}` maps. Nil-handling uses conventions like `@Updatable(nilIf: .isBangQualifiedEmpty)` — the `"!"`-placeholder-for-empty convention must be replicated precisely.
4. **`WriteAction`/update semantics.** `@RemotelyUpdatable` generates granular field-update writers. Android must write the same paths with the same value shapes — verify with RTDB diffing during Phase 5–8 acceptance runs (write from iOS, write from Android, diff the JSON exports).
5. **Fonts.** The San Francisco `.otf`s in `Sources/Resources/Other/San Francisco Font` are licensed for Apple platforms only and **must not ship in an Android app**. Recommend **Inter** (closest to SF metrics; open license) as the ComponentKit-equivalent default, with per-weight mapping mirroring ComponentKit's typeface/weight/scale model. This is the main structural concession inside the 80% visual-parity budget.
6. **Translation archive keys.** The hosted-translation archive in RTDB is keyed by hashed inputs. Android must produce identical keys or it will re-translate (and double-write) everything iOS already archived.
7. **Cache strategies & self-write suppression.** `CacheStrategy`, `SelfWriteRegistry`, and `invalidatedCaches` coordinate multi-client consistency. Port the *semantics*, not just the reads, or Android will echo its own writes back into the UI.
8. **Phone auth setup.** Firebase phone auth on Android requires SHA-1/SHA-256 fingerprints registered per build type and Play Integrity enabled; test numbers configured in the Firebase console (the iOS Developer Mode flow prefills a test number — mirror that).

---

## 7. MVP Feature Scope

**In scope:** phone-number onboarding (all six pages), user creation, splash/session restore, conversations list with live sync + search, 1:1 **text** chat with inline translation, read receipts, delivery states, typing indicator (stretch), new-conversation creation via contact selector, settings essentials (change language, blocked users, delete account, consent toggles), push notifications (receive), day/night theming, runtime-translated UI strings.

**Cut from MVP:** PenPals (`isPenPalsParticipant` written as `false`), group-chat *creation* (render multi-participant conversations read-only-gracefully if encountered), audio messages + audio translation, media (photo/video) messages, message reactions (render if present; author post-MVP), contextual long-press menu (use simple Compose menu), QR invite page, GIF/sticker content, prevarication mode, full Developer Mode (keep minimal debug menu: environment switcher, destroy data, log console).

Each cut is justified by lift-to-importance: audio/media are the heaviest subsystems in the codebase (recording, transcoding, Storage upload, playback UI) and are additive to the core "translated text conversation" use case.

---

## 8. Phased Plan

Phase ACs are written to be demonstrable — each ends with something you can run and see.

### Phase 0 — IDE Setup & Project Bootstrap

*You drive; Claude guides. Goal: a working Android toolchain and an empty-but-real project.*

- Install **Android Studio** (current stable); let it install the SDK, platform tools, and an emulator image (Pixel-class device, latest stable API).
- iOS-developer orientation: Gradle ≈ SwiftPM+xcodebuild; modules ≈ SPM targets; `build.gradle.kts` ≈ Package.swift; AVD ≈ Simulator; Logcat ≈ Console.
- Create the `panther-android` repo: **Empty Activity (Compose)** template, Kotlin DSL, version catalog (`libs.versions.toml`).
- Add module skeletons: `:app`, `:subsystem`, `:networking`, `:designsystem`, `:translator`.
- Configure ktlint + detekt with a baseline config derived from the style rules (§9).
- Firebase console work (needs your access): register Android app(s) on the existing Firebase project, download `google-services.json`, add debug SHA-1/SHA-256 fingerprints, enable Play Integrity for App Check, add a test phone number for auth.
- Set up build types/flavors mapping to `development`/`staging`/`production`.

**AC:** blank template app builds and runs in the emulator; `./gradlew lint detekt` passes; Firebase config files in place for dev.

### Phase 1 — Parity Groundwork + Architecture Kernel

*Goal: the AppSubsystem core exists in Kotlin, and schema drift is structurally prevented.*

- **Parity artifacts (do first, in the iOS repos):**
  - `SCHEMA.md` — every RTDB path, every serialized type, exact wire keys, encodings, nil conventions, hash-factor recipes; generated by reading all `*+Serializable.swift` + macro sources.
  - **Golden fixtures** — JSON files of encoded `User`, `Conversation`, `Message`, `ReadReceipt`, `Reaction`, etc., produced by the iOS code, committed to both repos; both platforms must decode → re-encode byte-identically.
  - `STYLE_RULES_ANDROID.md` — Kotlin adaptation of the style rules (§9).
- **Kernel port (`:subsystem`):** `Reducer` (sealed `Action` blocks mirroring the iOS ordering convention), `Effect` (`none`/`run`/`task`/`fireAndForget`, cancellation, merge), `ViewModel` (StateFlow + `binding`-equivalents for Compose), `Dependency`/`DependencyValues` registry with scoping, `SharedState`/`SharedEvents` (StateFlow/SharedFlow), `Exception` model + catalog pattern, `Logger` with domains, persistent storage (`RuntimeStorage`/UserDefaults-equivalents via DataStore), `LockIsolated`-equivalent (or document Kotlin-native concurrency idioms replacing it).
- Port the timestamp formatter and `EncodedHashable` **with fixture tests against iOS-produced values**.

**AC:** a sample counter/demo screen runs on a Kotlin reducer with effects and shared-event observation; kernel unit tests green; `EncodedHashable` and timestamp fixtures match iOS byte-for-byte.

### Phase 2 — Backend Foundation (Networking Core)

*Goal: read and write arbitrary values to the shared RTDB, correctly, from Android.*

- Port `DatabaseDelegate` surface onto Firebase Android RTDB: `getValues`, `setValue`, `updateChildValues`, `observe` (as `Flow`), `queryValues`, `runTransaction`, `increment`, `generateKey`, cache strategies, network-activity signaling.
- Port `Auth`: anonymous sign-in, phone verification (send code / sign in with code), sign-out; wire App Check (Play Integrity).
- Environment switching (dev/stage/prod path prefixing per `NetworkEnvironment`).
- Storage basics (download/upload primitives only — media features are post-MVP).
- Serialization framework: `Serializable`-equivalent interface + hand-written encoders/decoders for the Phase 1 schema types, validated against golden fixtures.

**AC:** a debug screen in the Android app reads and writes arbitrary values at arbitrary dev-environment RTDB paths; an `observe` Flow live-updates when the value is edited from the Firebase console (or the iOS app); fixture round-trip tests green; anonymous auth succeeds.

### Phase 3 — Design System & Navigation Shell

*Goal: the visual vocabulary of the iOS app, in Compose.*

- ComponentKit equivalent: `Components`-style factory API for styled text/buttons/symbols; typeface/weight/style/size model; **font decision executed** (Inter licensed-in, weight mapping documented); Material symbols or vector assets standing in for SF Symbols used by the app.
- Theming: port AppSubsystem theme model (day/night, `ThemedView` equivalent), Panther's `Themes` definitions, color constants.
- AlertKit equivalent: translation-aware alert/confirmation/error/progress/text-input dialogs in Compose with the same call-site API.
- Navigation: Compose Navigation shell mirroring `RootNavigator` + the four navigators (Onboarding, UserContent, Chat, Settings); `StatefulView` (loading/error/loaded) equivalent; toast/HUD utilities (CoreKit.UI analogs).
- Localization plumbing: convert `.lproj` tables to `strings.xml` (scripted), port `LocalizedStringKeys` + runtime translated-string resolution interfaces (stub translation until Phase 4).

**AC:** a gallery screen showing themed components, alerts, and navigation transitions side-by-side with iOS at ~80% visual match; day/night switching works.

### Phase 4 — Translation Stack

*Goal: Android translates strings the same way, against the same archive.*

- Port hosted translation: RTDB archive lookup/write (**identical archive keys** — fixture-test the key derivation), `TranslationInput`/`LanguagePair`/`Translation` models, input prevalidation and post-processing rules.
- Port Translator's WebView harness: hidden `WebView`, per-platform URL + JS extraction scripts, retry/fallback state machine; Google Translate first, then DeepL/Reverso/Lara as needed for reliability.
- Local translation cache; language recognition; the `LocalizedStrings.plist`-driven static-string flow feeding page-level "display string resolution" used by every reducer.
- Defer Gemini AI enhancement (post-MVP toggle; API-key delegate pattern ports trivially later).

**AC:** on-device demo translates an arbitrary EN string to ES via archive-miss → web translation → archive write; a second request hits the archive; archive entries are readable by the iOS app (verified by key equality and a cross-device test).

### Phase 5 — Onboarding & User Creation

*Goal: a new user, created entirely from Android, indistinguishable from an iOS-created one.*

- Port all six pages + reducers against their iOS behavior contracts: Welcome, SelectLanguage, SignIn, VerifyNumber, AuthCode, Permission (+ InstructionView, RegionMenu components), `OnboardingService`, splash page/session restore.
- Phone-number handling via libphonenumber matching PhoneNumberKit behavior (calling codes from `CallingCodes.plist`, ported to a bundled resource).
- `User` serialization + creation write; push-token registration stubbed until Phase 8.
- Permission page maps to Android runtime permissions (notifications, contacts).

**AC:** complete onboarding on the Android emulator/device creates a dev-environment user; the RTDB record diffs clean against an iOS-created user (allowing only `deviceID`/token differences); signing into that account from iOS works.

### Phase 6 — Conversations List

*Goal: an existing user's world renders and stays live on Android.*

- Port the session layer subset: `SessionStore`, `UserSessionService`/`ConversationSessionService`/`MessageSessionService` read paths, `ConversationObserverService`/`ConversationSyncService` (RTDB observers → SharedEvents), `SelfWriteRegistry` semantics.
- Port `UserService`, `ConversationService`, `MessageService` read paths + `Conversation`/`Message`/`Participant`/`Activity` decoding (fixtures already exist from Phase 1).
- UI: ConversationsPage + ConversationCell + search, unread badges, contact-name resolution (contacts permission + lookup service), UserContentContainer shell.

**AC:** sign in as an existing seeded user on Android; the conversation list renders with correct titles, previews, timestamps, and unread states; sending a message from iOS updates the Android list live.

### Phase 7 — Chat (Text)

*Goal: bidirectional Android↔iOS conversation. The MVP's heart, and the largest single phase.*

- Build ChatPage natively in Compose: message list (`LazyColumn`, reverse layout, day separators, bubble styling per iOS), input bar, send flow, delivery-progress indicator, read receipts, scroll/pagination behavior, typing indicator (stretch).
- Port the send pipeline: `MessageOutboxService` + retry, message translation on send (Phase 4 stack), `MessageService.send`, conversation `Activity` updates, read-receipt writes, `ChatPageStateService` equivalents.
- Render-side: translation display logic (original vs. translated, per-user language), message grouping, error/retry states.
- Explicitly **not** ported: MessageKit abstractions, ContextualMenu vendored code, media/audio cells (placeholder bubble for unsupported content types).

**AC:** two devices (Android + iOS) hold a live conversation in two languages: messages arrive translated, read receipts flow both ways, offline-composed messages send on reconnect, and the iOS app renders Android-authored messages (and vice versa) with zero schema warnings.

### Phase 8 — Write Parity & Push Notifications

*Goal: every backend mutation the MVP surface needs, plus pushes.*

- New-conversation flow: NewChatPage + ContactSelectorPage, `ConversationStagingService`, conversation creation writes (ID + hash generation fixture-tested).
- Remaining mutations: block/unblock, report user, delete conversation, leave/delete account (`deletedUsers`), language change (`ChangeLanguagePage` + `previousLanguageCodes`), consent toggles, badge counts, `pushTokens` registration/removal.
- Investigate the push pipeline from the iOS side (NotificationExtension + how sends are triggered), then implement FCM receive: `FirebaseMessagingService`, token lifecycle, notification channels, deep-link into conversation.
- Produce the **endpoint parity checklist**: every write the iOS app performs (grep `WriteAction`/service mutation surface) → Android status. MVP-cut features are marked N/A, not forgotten.

**AC:** parity checklist complete with all in-scope rows green (verified by RTDB export diffing after scripted parallel runs); Android receives a push for a new message with the app backgrounded and opens to the right conversation.

### Phase 9 — Polish & Play Store Release

*Goal: an MVP you'd let strangers install.*

- Settings page completion; FeaturePermissionPage analogs; empty/error/edge states; interruption handling (process death, connectivity loss — Android-specific lifecycle testing).
- Visual parity pass against iOS screen-by-screen (target ≥80%: spacing, typography scale, dark mode, animations where cheap).
- Performance (startup, list scrolling, translation latency), release hardening (R8/ProGuard rules for Firebase/WebView reflection), accessibility basics (TalkBack labels, touch targets).
- Play Store: signing setup (Play App Signing), listing assets, data-safety form (chat app: expect scrutiny on contacts/phone-number usage), privacy policy, **internal testing track → closed track** rollout.
- Post-MVP backlog written up: audio messages, media messages, reactions authoring, PenPals, group chats, Gemini enhancement, contextual menus.

**AC:** release build on the closed testing track; a fresh tester can install, onboard, and chat with an iOS user; crash-free sessions through a week of dogfooding.

---

## 9. Can Claude Code Follow the iOS Style Rules on Android?

**Mostly yes — the structural rules transfer nearly intact; the Swift-syntax rules need a documented Kotlin mapping.** Recommended: produce `STYLE_RULES_ANDROID.md` in Phase 1 rather than letting each session improvise. Assessment by rule group:

**Transfers directly (≈60%):** module directory taxonomy (Components/Constants/Dependencies/Extensions/Models/Protocols/Services/Views — with `View Modifiers` → `Modifiers` and `Protocols` → `Interfaces` as one-word renames); file-naming patterns (`(Name)Reducer.kt` beside `(Name)View.kt`); reducer↔view 1:1 mapping and reducer anatomy (Dependencies/Actions/State/Reduce section order, action grouping and naming — `<operation>Returned`/`<operation>Failed`); `AppConstants` architecture (Kotlin `object` nesting replaces case-less enums); alphabetical-ordering rules; file headers; conservative property declaration; size limits (enforceable via detekt); no `Helpers`/`Utils` directories.

**Transfers with adaptation:** multi-line call expansion (Kotlin named arguments make 10.1/10.2 natural; encode as ktlint config where possible); guard formatting → early-`return` patterns (`?: return` idioms; document the mapping since Kotlin has no `guard`); import grouping — **conflict**: ktlint enforces a single alphabetized import list and Kotlin tooling fights comment-separated groups; recommend accepting IDE-standard import ordering as a documented deviation; `// MARK: -` → `// region` markers or plain comment conventions (document one).

**Doesn't apply:** `LockIsolated` syntax rules (Kotlin concurrency differs — document the replacement idiom), SwiftUI modifier-chain rules (map the spirit to Compose modifier chains: alphabetize where order-independent), extensions policy (Kotlin extension functions have different file conventions — adapt), `final` by default (Kotlin classes are final by default).

**Practical guidance for the porting instance:** put `STYLE_RULES_ANDROID.md` + ktlint/detekt configs in the repo root, and reference it from the repo's `CLAUDE.md` so every session loads it. Claude Code follows explicit written rules well; ambiguity (not capability) is what produces drift, and the iOS rules are unusually explicit — the Kotlin adaptation preserves that property.

---

## 10. Key File Pointers for the Porting Instance

| Concern | Read first |
|---|---|
| Reducer/Effect/ViewModel semantics | `app-subsystem/Sources/Modules/Reducer/`, `Modules/Effect/`, README §Architecture |
| DI registry | `app-subsystem/Sources/Modules/Dependency Injection/` |
| Shared state/events | `app-subsystem/Sources/Modules/Shared/` |
| Identity hashing | `app-subsystem/.../Protocols/Public/EncodedHashable.swift` |
| Timestamp wire format | `app-subsystem/.../Dependencies/Public/TimestampDateFormatterDependency.swift` |
| Database API surface | `networking/Sources/Modules/Database/Protocols/DatabaseDelegate.swift`, `Services/CoreDatabase.swift` |
| Serialization macro semantics | `networking/Sources/Macros/`, `Modules/Common/Models/Public/Macros/` |
| Phone auth | `networking/Sources/Modules/Auth/Services/Auth.swift` |
| Hosted translation | `networking/Sources/Modules/Translation/Services/HostedTranslationService.swift` |
| Web translation harness | `translator/Sources/Services/Internal/BaseTranslator.swift` (+ `+Scripts.swift`) |
| RTDB paths | `panther/Sources/Bundle/NetworkPaths.swift` |
| Schema (all types) | `panther/Sources/Modules/Networking/Sources/*/Serializable/` + `Models/` |
| Session/sync loop | `panther/Sources/Modules/Session/` |
| Onboarding contracts | `panther/Sources/Modules/Content/Onboarding/Views/*/​*Reducer.swift` header docs |
| Conversations UI | `panther/Sources/Modules/Content/User/Views/ConversationsPageView/` |
| Chat (for behavior, not structure) | `panther/Sources/Modules/Content/User/Views/ChatPageView/`, `Services/ChatPageView/Sources/` |
