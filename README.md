# SheSafe

A women's safety app built with Flutter (Android first), with a Firebase server.

**Status: version 0.2, not tested on a real phone yet.** It has not been compiled or run,
so expect to fix a few small errors on first build. Until Firebase is set up (below) the
app runs in **DEMO MODE**: all screens work, but no real alert is sent to anyone.
Do not rely on this app in a real emergency. Call 112.

## What it does

| Area | What it does |
|---|---|
| **Home** | Only the big SOS button. Hold it 1 to 3 seconds so it cannot be pressed by accident. |
| **During SOS** | Alerts her trusted contacts and nearby SheSafe users, shares live location, and shows who saw it, who is on the way and who is calling. Her phone ticks each time someone responds. |
| **Family alert screen** | Opens full screen on a locked phone (Android): siren, repeating vibration, her live location, "I'm on my way" (she sees it), Call, Silence. Stops by itself when she taps "I'm safe". |
| **Nearby women** | Women within her radius (200 m to 3 km) get a calmer alert with only a rough distance. Her exact live location opens only after they tap "I can help". |
| **Contacts, Nearby, Tools, Settings** | Trusted contacts, help nearby (maps), fake call, siren, SMS location share, safe check-in timer, emergency numbers, preferences. |

## How alerts travel

```
her phone ──creates sos/{id}──▶ Firestore ──▶ Cloud Function (functions/index.js)
                                                 ├─▶ push to trusted contacts (matched by phone number)
                                                 └─▶ push to registered users inside her radius
family phone ◀── full-screen alert ── FCM
family phone ──writes sos/{id}/responses/{uid}──▶ her phone shows "on the way"
her phone ──writes sos/{id}/live/loc every ~5 m──▶ family phone shows live location
```

## Setup

### 0. Easiest: let GitHub build the APK (no Flutter install)
1. Create a free GitHub account and a new **private** repository.
2. Upload everything from this folder to it (keep the `.github` folder), on the `main` branch.
3. Open the **Actions** tab, choose **Build SheSafe APK**, press **Run workflow**. It takes about 10 minutes.
4. Open the finished run and download **shesafe-apk**. Unzip it, copy `app-release.apk` to your Android phone and install it (allow "install unknown apps" when asked).
5. This first build is **demo mode**. To build with Firebase, finish steps 2 and 4 below first, then in the repository go to Settings > Secrets and variables > Actions, add a secret named `GOOGLE_SERVICES_JSON` with the full contents of your `google-services.json`, and run the workflow again. The Firebase Android app must use the package name `com.shesafe.shesafe`.

The build has never been run, so the first attempt may fail. If it does, open the failed run, copy the red error lines and send them to me.

### 1. Flutter project (if you prefer to build on your own computer)
1. Install Flutter 3.27 or newer.
2. `flutter create --org com.shesafe --project-name shesafe shesafe_app`
3. Copy `lib/`, `assets/` and `pubspec.yaml` from this folder into `shesafe_app/`, replacing what is there.
4. Also copy `firebase.json`, `firestore.rules`, `firestore.indexes.json` and the `functions/` folder next to it (into `shesafe_app/`).

### 2. Firebase project (needs your Google account)
1. Go to https://console.firebase.google.com and create a project.
2. Add an **Android app** with package name `com.shesafe.shesafe`, and download `google-services.json` into `shesafe_app/android/app/` (or keep it for the GitHub secret in step 0).
3. Add your **SHA-1** key in Project settings > your Android app. Get it with `cd android && ./gradlew signingReport`.
4. **Authentication > Sign-in method:** enable **Phone**. While testing, add fake test numbers (with a fixed code) under "Phone numbers for testing" to avoid sending real SMS.
5. **Firestore Database:** create one (production mode).
6. Upgrade to the **Blaze (pay-as-you-go)** plan. Cloud Functions need it. The free allowance is large, so a small test costs little or nothing, but check the pricing page.

### 3. Android project files (inside `shesafe_app/android/`)
- `settings.gradle.kts` (or `.gradle`), in the plugins block add:
  `id("com.google.gms.google-services") version "4.4.2" apply false`
- `app/build.gradle.kts` (or `.gradle`):
  - plugins: `id("com.google.gms.google-services")`
  - `minSdk = 23`
  - in `compileOptions`: `isCoreLibraryDesugaringEnabled = true`
  - dependencies: `coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")`
- `app/src/main/AndroidManifest.xml`, before `<application>`:
  ```xml
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>
  <uses-permission android:name="android.permission.VIBRATE"/>
  <uses-permission android:name="android.permission.WAKE_LOCK"/>
  <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
  <uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>
  <queries>
    <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="tel"/></intent>
    <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="sms"/></intent>
    <intent><action android:name="android.intent.action.VIEW"/><data android:scheme="https"/></intent>
  </queries>
  ```
  and on the `<activity android:name=".MainActivity" ...>` tag add
  `android:showWhenLocked="true" android:turnScreenOn="true"` so the alert can appear over the lock screen.

### 4. Deploy the server
```
npm install -g firebase-tools
firebase login
firebase use --add            # pick your project
cd functions && npm install && cd ..
firebase deploy --only firestore,functions
```
Choose the same region as your Firestore database when asked.

### 5. Try it with two phones
1. Phone A and phone B each install the app and sign in with different numbers.
2. On phone A, add phone B's number as a trusted contact.
3. Press and hold SOS on phone A. Phone B should get the full-screen alert.
4. Tap "I'm on my way" on B. Phone A shows it.
5. For nearby alerts, sign in a third phone, keep it within the radius and open the app once so its location is saved.

If `flutter run` cannot find Firebase, the app falls back to demo mode and prints why in the log.

## Do these before real users
1. **Consent.** Today anyone who types your number as a "trusted contact" will get your phone ringing with their SOS alerts if you are registered. Someone could abuse that to harass you. Add an invite the person must accept before alerts reach them.
2. **Do Not Disturb.** On the family member's phone: Settings > Apps > SheSafe > Notifications > "SOS alerts" > turn on "Override Do Not Disturb". An app cannot switch this on by itself.
3. **Keep sharing location when the screen is off.** Add an Android foreground service. The check-in timer needs this too. At the moment both only work while the app is open.
4. **Nearby location is only refreshed** when the app opens or settings change, and users not seen in 48 hours are skipped. A foreground service or periodic background job would make nearby alerts reliable.
5. **Auto-answer calls** during an SOS is not built. It needs Android-only native code with the `ANSWER_PHONE_CALLS` permission. Check Google Play policy first. The per-contact switch in Contacts is saved but does nothing yet.
6. **iPhone.** Not set up. Silent-mode alerts there need Apple's Critical Alerts approval.
7. **Privacy and legal.** You will be storing phone numbers and live locations of vulnerable people. Add a privacy policy, delete SOS records after a set time, and review the Firestore rules with someone experienced before launch.
8. Test it properly: real phones, locked screen, weak network, battery saver on.

## Folder map
```
lib/main.dart                    start-up; falls back to demo mode without Firebase
lib/state.dart                   app state: contacts, settings, SOS, check-in
lib/services/backend.dart        server interface + DemoBackend
lib/services/firebase_backend.dart   the real server code (Firestore)
lib/services/push_service.dart   push notifications and full-screen alert
lib/pages/                       home, contacts, nearby, tools, settings, login, fake call, family alert
functions/index.js               Cloud Function that sends the alerts
firestore.rules                  who may read and write what
```
